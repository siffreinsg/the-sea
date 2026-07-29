# Reference values

The constants. Everything here is looked up, not reasoned about.

| | |
|---|---|
| Domain | **siffreinsigy.me** — Cloudflare, DNS-only (grey cloud) |
| Wildcard | `*.siffreinsigy.me` → Thriller Bark. One level only |
| Contact mail | `hello@siffreinsigy.me` (ACME + Authelia user) |
| Mesh IPs | TB `100.64.0.2`, GM `100.64.0.1`. Base domain `mesh.siffreinsigy.me` |
| Public IPs | TB `141.253.109.196`, GM `62.4.16.10` |
| Open ports | TB 80/443/22 · GM 4747 (SSH) · nothing else. **Planned, not yet open:** TB 22000/tcp+udp for Syncthing ([the one exception](ADR/2026-07-26-syncthing-public-port.md)) — needs the Docker publish *and* an Oracle VCN security-list rule |
| Container network | `the-sea-internal` on TB — hand-created (`docker network create`), `external: true` in every compose that joins it. For containers that must dial each other by name |
| Repo on nodes | `/opt/the-sea` ← `git@github.com:siffreinsg/the-sea.git`, `main` |
| age recipient | `age1wce7sqneyq58tux6fnpj2e2tsc05j4jqk8h8dguu0jc6eplfrslqqdw7md` |
| age private key | password manager + `/etc/sops/age.key` (root, 0600) on each node |
| Dumps | `/var/backups/the-sea/dumps/` (0700) |
| GM legacy data | `/home/siffrein/docker-mei/` — map in [legacy inventory](legacy/going-merry-inventory.md) |

## Schedules (UTC)

| Job | Time |
|---|---|
| DB dumps | TB 03:00, GM 04:00 — each an hour ahead of its own node's first plan |
| TB bulk / critical | 04:00 / 04:30 |
| GM bulk / critical | 05:00 / 05:30 |
| Unattended-upgrades reboot (TB) | 02:00 |

TB and GM authenticate to the **same Proton account**, and simultaneous re-auths trigger
`429 Too many recent logins`. That is why the nodes are staggered an hour apart — keep
the offset if you change these.

## Web UIs

| Service | URL |
|---|---|
| Komodo | `komodo.siffreinsigy.me` |
| Authelia | `auth.siffreinsigy.me` |
| Grafana | `grafana.siffreinsigy.me` |
| Backrest | `backrest-tb.siffreinsigy.me`, `backrest-gm.siffreinsigy.me` |
| Headscale | `headscale.siffreinsigy.me` |
| Health check | `up.siffreinsigy.me` → `the sea is up` |
| Actual Budget | `actual.siffreinsigy.me` |
| n8n | `n8n.siffreinsigy.me` |
| LiteLLM | `ai.siffreinsigy.me` |
| Open-WebUI | `chat.siffreinsigy.me` |
| Dawarich | `dawarich.siffreinsigy.me` |
| your_spotify | `spotify.siffreinsigy.me` |
| Profilarr | `profilarr.siffreinsigy.me` |
| Cleanuparr | `cleanuparr.siffreinsigy.me` |
| Overseerr (legacy redirect) | `overseerr.blackpearl.siffreinsigy.me` |
| Uptime-Kuma | on Sunny (`app-uptimekuma`), **not behind Caddy** — external node-liveness for TB and GM, the mitigation for observability living on a watched node ([ADR](ADR/2026-07-23-observability-on-going-merry.md)) |

This table and `thriller-bark/caddy/Caddyfile` are exhaustive of each other — 15 hosts,
verified. All are `@name host` matchers inside the wildcard block except
`overseerr.blackpearl`, which is its own site block (a `redir`, not a proxy), and
Uptime-Kuma, which is not behind Caddy at all. If you add a Caddy block for a hostname,
add a row. The relay listeners below are the one part of the Caddyfile with no hostname.

## Caddy mesh relay

Not public, no hostname, no TLS. How a bridged TB container reaches a GM service that has
no auth of its own ([why](ADR/2026-07-29-caddy-relays-mesh-services-to-containers.md)).
Callers use `http://host.docker.internal:<port>`.

| Port | Backend |
|---|---|
| `8090` | SearXNG, `100.64.0.1:8080` |
| `8091` | Firecrawl, `100.64.0.1:3002` — reserved, lands with the service |

## Restic repositories

```
rclone:proton:restic/<node>            # bulk
rclone:mega:restic/<node>-critical     # critical
```

`<node>` is the **full** ship name (`thriller-bark`), never `tb` —
see [the naming decision](ADR/2026-07-21-full-node-names-for-dr-identifiers.md).
Instance and restic passwords live in the password manager and are, with the age key,
**the DR root of trust**.
