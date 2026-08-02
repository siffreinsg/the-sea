# Reference values

The constants. Everything here is looked up, not reasoned about.

| | |
|---|---|
| Domain | **siffreinsigy.me** — Cloudflare, DNS-only (grey cloud) |
| Wildcard | `*.siffreinsigy.me` → Thriller Bark. One level only |
| Contact mail | `hello@siffreinsigy.me` (ACME + Authelia user) |
| Mesh IPs | TB `100.64.0.2`, GM `100.64.0.1`. Base domain `mesh.siffreinsigy.me` |
| Public IPs | TB `141.253.109.196`, GM `62.4.16.10` |
| Open ports | TB 80/443/22/22000 (Syncthing BEP, [the one exception](ADR/2026-07-26-syncthing-public-port.md)) · GM 4747 (SSH) · nothing else |
| sshd hardening <!-- mirrors ssh/hardening.conf + <node>/ssh/local.conf — verify: diff against /etc/ssh/sshd_config.d/ on each node --> | Shared: key-only, no root login, no PAM, `MaxAuthTries 3` (`ssh/hardening.conf`, same file on both nodes). Per-node: TB bound to `10.0.0.112:22` (private NIC IP — OCI NATs the public IP, binding it directly means nothing arrives), `AllowUsers ubuntu`; GM bound to `62.4.16.10:4747`, `AllowUsers siffrein`. See [networking.md](domains/networking.md) |
| `edge` network | TB — hand-created (`docker network create edge`), `external: true` in every compose that joins it. Every non-n8n service Caddy reverse-proxies to by container name |
| `ai-backends` network | TB — hand-created (`docker network create ai-backends`), `external: true` in open-webui, litellm, tika. Lets open-webui dial its AI backend and doc-extraction service by name |
| `n8n-edge` network | TB — hand-created (`docker network create n8n-edge`), `external: true` in n8n and caddy only. n8n runs user-supplied code, so it's isolated from `edge`'s other members (headscale, authelia, backrest) instead of sharing the flat network |
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
| Karakeep | `karakeep.siffreinsigy.me` |
| Home Assistant | `home.siffreinsigy.me` — own login, no Authelia |
| Syncthing | `syncthing.siffreinsigy.me` |
| Overseerr (legacy redirect) | `overseerr.blackpearl.siffreinsigy.me` |
| Uptime-Kuma | on Sunny (`app-uptimekuma`), **not behind Caddy** — external node-liveness for TB and GM, the mitigation for observability living on a watched node ([ADR](ADR/2026-07-23-observability-on-going-merry.md)) |

This table and `thriller-bark/caddy/Caddyfile` are exhaustive of each other — 19 hosts,
verified. All are `@name host` matchers inside the wildcard block except
`overseerr.blackpearl`, which is its own site block (a `redir`, not a proxy), and
Uptime-Kuma, which is not behind Caddy at all. If you add a Caddy block for a hostname,
add a row. `thriller-bark/gm-relay/Caddyfile` is a separate file, not part of this table.

## GM relay

`thriller-bark/gm-relay/` — a second, host-mode Caddy instance. Every GM-bound hostname's
backend now points here instead of `100.64.0.1:<port>` directly (main Caddy is
bridge-networked since this redesign and can't dial the mesh itself). Binds `0.0.0.0`,
same reasoning as Alloy's OTLP receiver ([why](domains/networking.md)) — callers use
`host.docker.internal`, never a literal gateway IP.

| GM service | GM port | gm-relay port |
|---|---|---|
| Dawarich | 3200 | 13200 |
| Backrest | 9898 | 19898 |
| Grafana | 3000 | 13000 |
| Profilarr | 6868 | 16868 |
| Cleanuparr | 11011 | 11011 |
| your_spotify | 8095 | 18095 |
| SearXNG | 8080 | 18090 |
| Playwright | 3002 | 18091 |
| Karakeep | 3050 | 13050 |
| Home Assistant | 8123 | 18123 |

SearXNG and Playwright have no auth of their own — callers on TB reach them via
`http://host.docker.internal:18090`/`:18091`, same as before this redesign, just renumbered.

## Headscale ACL

`thriller-bark/headscale/acl.hujson` — port-level TB→GM allowlist, additive to the mesh
guard, not a replacement for it ([why](ADR/2026-08-01-per-stack-networks-and-headscale-acl.md)).
Covers exactly what needs to cross the mesh from the host side: Alloy's OTLP push and
gm-relay's 9 hops (the table above). Nothing else is allowed TB→GM, and nothing is
allowed GM→TB.

| Service | Port |
|---|---|
| VictoriaMetrics remote_write | 8428 |
| Loki push | 3100 |
| Tempo OTLP gRPC | 4317 |
| Dawarich | 3200 |
| Backrest-GM | 9898 |
| Grafana | 3000 |
| Profilarr | 6868 |
| Cleanuparr | 11011 |
| your_spotify | 8095 |
| SearXNG | 8080 |
| Playwright | 3002 |
| Karakeep | 3050 |

## Restic repositories

```
rclone:proton:restic/<node>            # bulk
rclone:mega:restic/<node>-critical     # critical
```

`<node>` is the **full** ship name (`thriller-bark`), never `tb` —
see [the naming decision](ADR/2026-07-21-full-node-names-for-dr-identifiers.md).
Instance and restic passwords live in the password manager and are, with the age key,
**the DR root of trust**.
