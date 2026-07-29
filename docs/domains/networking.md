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
  the existing one. The Caddyfile targets this address directly.
- Sunny is [not on the mesh](../ADR/2026-07-25-sunny-stays-off-the-mesh.md) and does
  not need to be.
- Headscale has **no ACL policy** — the tailnet is allow-all between members. That is
  tolerable only because membership is two trusted nodes; see the container trap below.

## Binds

Every published port binds a private address: `127.0.0.1` on TB, `100.64.0.1` on GM.
**Never `0.0.0.0`** — and don't "fix" a bind to a bridge network to make something
reachable. Only Caddy and Komodo Core use `network_mode: host`, because they dial mesh
addresses themselves. ([The rule and why](../ADR/2026-07-19-services-bind-private-addresses.md).)

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

### Containers must not reach the tailnet

Docker's per-bridge MASQUERADE plus Tailscale's `ts-forward` accept let every bridged
container on TB route onto `100.64.0.0/10`. That breaks the premise VictoriaMetrics and
Loki rely on — proven from inside n8n, a workflow engine that runs user-supplied code,
which pulled unauthenticated 200s from both.

Closed by `thriller-bark/firewall/the-sea-mesh-guard.service`, a oneshot that DROPs the
traffic in **raw/PREROUTING**. The chain choice is not incidental and neither is
`PartOf=docker.service`: [see the decision](../ADR/2026-07-25-mesh-guard-in-raw-prerouting.md).

**The guard is installed on TB only — GM has no `firewall/` dir and its bridged containers
can still reach `100.64.0.0/10`.** That is a known gap, not an oversight: the threat is a
user-code engine and the only one (n8n) is on TB. It stays fixable because no GM container
needs the mesh, so a copy of the unit can land there whenever we want it. The mesh is for
`network_mode: host` infrastructure — Alloy, Caddy, Komodo — which the guard does not touch.

### Reaching a GM service from a TB container

The guard means a bridged container cannot dial `100.64.0.1` at all. Two sanctioned paths,
picked by whether the callee can authenticate itself
([decision](../ADR/2026-07-29-caddy-relays-mesh-services-to-containers.md)):

| Callee | Path |
|---|---|
| Has its own auth (LiteLLM virtual keys) | public edge, `https://<app>.siffreinsigy.me` |
| Has none (SearXNG, Firecrawl) | Caddy relay listener, outside the wildcard site |

The relay is a plain `reverse_proxy` on its own port in `thriller-bark/caddy/Caddyfile`:
`:8090` → SearXNG, `:8091` → Firecrawl (reserved). Callers use
`http://host.docker.internal:<port>` with `extra_hosts: host-gateway`, never a literal
gateway IP. Caddy is `network_mode: host`, so the hop to GM is the host's traffic and the
guard never sees it — the same shape as [OTLP to Alloy](observability.md).

These listeners bind `0.0.0.0`, the **third** exception to the bind rule, for the reason
Alloy's OTLP receiver has the same one: senders sit on two different bridges and gateway
IPs change when a network is recreated. The perimeter firewall is the gate.

## DNS

Cloudflare, DNS-only. `*.siffreinsigy.me` points at TB, so a new service needs no DNS
record — with one trap:

**A wildcard does not cover a name that already has any record.** Standard DNS, not a
Cloudflare quirk: a name holding even an unrelated MX record goes NODATA instead of
falling through to the wildcard. Check the exact name in Cloudflare before picking a
subdomain. This bit Authelia's hostname twice, and is why the
`overseerr.blackpearl` redirect needs its own site block — the wildcard covers one level
only.
