# Networking

One machine faces the internet. Everything else is reachable only over the mesh.

## Mesh — Headscale

Headscale runs on TB behind Caddy and is the control plane for a Tailscale mesh of
exactly two members: TB `100.64.0.2` and GM `100.64.0.1`. All inter-node traffic —
Komodo, metrics, logs, backups, reverse-proxying — goes over it.
([Why Headscale](../ADR/2026-07-18-headscale-mesh.md).)

- GM runs **kernel mode** (its OpenVZ host exposes `/dev/net/tun`).
- **GM's `100.64.0.1` is a procedural pin** — DB-persisted and stable across reboots, but
  it changes if the node is deleted and re-added. **Never delete that node**, re-register
  the existing one. `gm-relay` targets this address directly.
- Sunny is [not on the mesh](../ADR/2026-07-25-sunny-stays-off-the-mesh.md) and does
  not need to be.
- Headscale has a **port-level TB→GM ACL** — see § Cross-node enforcement below.

## Binds

Every published port binds a private address: `127.0.0.1` on TB, `100.64.0.1` on GM.
**Never `0.0.0.0`**, with three exceptions (`AGENTS.md`): Alloy's OTLP receiver
(`thriller-bark/alloy/config.alloy`, `0.0.0.0:4317/4318`) and `gm-relay`'s eight loopback
proxies (`thriller-bark/gm-relay/Caddyfile`) — both because a bridged sender's gateway IP
is not a fixed, predictable address to bind instead — plus Syncthing's `22000`, the only
*publicly reachable* one, unrelated reasoning
([why](../ADR/2026-07-26-syncthing-public-port.md)). Don't "fix" a bind to a bridge
network to make something reachable — that only works when a stack has exactly one,
permanent gateway IP, which most don't. Caddy's own `80`/`443` isn't in this count: it's
the public edge, not an exception to a private-bind rule.
Only `gm-relay` and Komodo Core use `network_mode: host` on TB, because they dial mesh
addresses themselves — main Caddy is bridge-networked and reaches both over
`host.docker.internal` instead.
([The rule and why](../ADR/2026-07-19-services-bind-private-addresses.md).)

Anything on GM binding `100.64.0.1` must be ordered `After=tailscaled` — the address does
not exist until the mesh is up.

## Firewall

Inbound: **80/443/22 on TB, 4747 on GM**, nothing else. GM carried a leftover ufw
"Nginx Full" allow from the nginx-proxy-manager era until 2026-07-25; it mattered because
default-deny is what makes a `0.0.0.0` bind mistake survivable, and on those two ports it
would not have been.

Two properties worth keeping, both verified by connection rather than by reading rules:

- **Every Docker publish is loopback- or mesh-scoped**, so Docker's usual
  publish-past-the-firewall problem does not apply here.
- **Containers reach the host, and that is load-bearing.** The INPUT default REJECT does not
  block a bridge gateway: from LiteLLM, `172.17.0.1` and `172.24.0.1` both return
  `ECONNREFUSED` on a closed port, and a **connect to `172.24.0.1:4318` succeeds** with
  Alloy listening (2026-07-27). A closed port is not an unreachable bridge — don't read
  `EHOSTUNREACH` on one port as the firewall blocking the whole range.

  The trace path depends on this — apps push OTLP to Alloy on the host
  ([observability](observability.md)). Anything binding a non-loopback address on TB is
  therefore reachable by every container, including n8n, which runs user-supplied code.
  Bind `127.0.0.1` unless a container genuinely has to reach it.

### Cross-node enforcement — two mechanisms, two different jobs

**The mesh guard** (`thriller-bark/firewall/the-sea-mesh-guard.service`, and its GM twin
at `going-merry/firewall/the-sea-mesh-guard.service`) DROPs bridged-container traffic to
the mesh in `raw/PREROUTING`, before Docker's per-bridge MASQUERADE rewrites it to the
host's own tailnet IP. This is the only mechanism that can do this job: once MASQUERADE
has run, GM cannot tell a container's traffic from the host's, so a Headscale ACL has
nothing to key on. ([Why it lives in raw/PREROUTING](../ADR/2026-07-25-mesh-guard-in-raw-prerouting.md).)
Installed on **both** nodes as of this redesign — previously TB-only, which left GM's
bridged containers able to reach the full mesh.

**The Headscale ACL** (`thriller-bark/headscale/acl.hujson`) is a port-level TB→GM
allowlist for genuinely mesh-native (host-originated) traffic — Alloy, gm-relay, Komodo,
backups — see `docs/REFERENCE.md` for the exact port table. It does not, and cannot,
replace the guard: it only sees packets after MASQUERADE, so it has no way to
distinguish a container's traffic from the host's. Both nodes' hosts must be tagged
(`headscale nodes tag`) before this allowlist takes effect — an untagged node is
default-deny, which would otherwise silently kill the metrics pipeline. Verify with
`headscale nodes list` before considering the ACL live.

### Reaching a GM service from a TB container

Main Caddy is bridge-networked and can't dial the mesh itself. GM-bound calls go through
`thriller-bark/gm-relay/`, a second host-mode Caddy instance on TB that reverse-proxies a
loopback port to each GM service's `100.64.0.1:<port>`
([why](../ADR/2026-07-29-caddy-relays-mesh-services-to-containers.md)). Callers reach it
via `host.docker.internal:<loopback port>`, never a literal gateway IP — see
`docs/REFERENCE.md` § GM relay for the port table.

## DNS

Cloudflare, DNS-only. `*.siffreinsigy.me` points at TB, so a new service needs no DNS
record — with one trap:

**A wildcard does not cover a name that already has any record.** Standard DNS, not a
Cloudflare quirk: a name holding even an unrelated MX record goes NODATA instead of
falling through to the wildcard. Check the exact name in Cloudflare before picking a
subdomain. This bit Authelia's hostname twice, and is why the
`overseerr.blackpearl` redirect needs its own site block — the wildcard covers one level
only.
