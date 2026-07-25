# Reference values

The constants. Everything here is looked up, not reasoned about.

| | |
|---|---|
| Domain | **siffreinsigy.me** — Cloudflare, DNS-only (grey cloud) |
| Wildcard | `*.siffreinsigy.me` → Thriller Bark. One level only |
| Contact mail | `hello@siffreinsigy.me` (ACME + Authelia user) |
| Mesh IPs | TB `100.64.0.2`, GM `100.64.0.1`. Base domain `mesh.siffreinsigy.me` |
| Public IPs | TB `141.253.109.196`, GM `62.4.16.10` |
| Open ports | TB 80/443/22 · GM 4747 (SSH) · nothing else |
| Repo on nodes | `/opt/the-sea` ← `git@github.com:siffreinsg/the-sea.git`, `main` |
| age recipient | `age1wce7sqneyq58tux6fnpj2e2tsc05j4jqk8h8dguu0jc6eplfrslqqdw7md` |
| age private key | password manager + `/etc/sops/age.key` (root, 0600) on each node |
| Dumps | `/var/backups/the-sea/dumps/` (0700) |
| GM legacy data | `/home/siffrein/docker-mei/` — map in [legacy inventory](legacy/going-merry-inventory.md) |

## Schedules (UTC)

| Job | Time |
|---|---|
| DB dumps (both nodes) | 03:00 — an hour ahead of the first plan |
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

## Restic repositories

```
rclone:proton:restic/<node>            # bulk
rclone:mega:restic/<node>-critical     # critical
```

`<node>` is the **full** ship name (`thriller-bark`), never `tb` —
see [the naming decision](decisions/2026-07-21-full-node-names-for-dr-identifiers.md).
Instance and restic passwords live in the password manager and are, with the age key,
**the DR root of trust**.
