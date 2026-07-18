# The Sea — Infrastructure Foundation Design

A reproducible, backed-up, unified homelab. Everything defined in Git, one dashboard to deploy across all Docker nodes. Kubernetes doesn't fit the node constraints, so: Komodo + Compose.

> This document specs the **foundation** only — the cross-cutting layers every later service migration depends on. Individual app migrations are separate sub-projects. Deferred items live in [future.md](future.md).

## Nodes

| Ship name              | Machine                           | Role                      | Container runtime                 |
| ---------------------- | --------------------------------- | ------------------------- | --------------------------------- |
| **Thriller Bark**      | Oracle Cloud ARM (4 vCPU / 24 GB) | Workhorse + control plane | Docker + Komodo agent             |
| **Going Merry**        | Omgserv OpenVZ VPS (old kernel)   | Legacy/light Docker node  | Docker + Komodo agent             |
| **The Thousand Sunny** | Ultra.cc box (no sudo, no Docker) | Media + download node     | Ultra.cc managed `app-*` services |
| **Den Den Mushi**      | Raspberry Pi                      | Home Assistant            | HAOS (managed, not Komodo)        |

- Major services run on **Thriller Bark**. Services without performance requirements or low sensitivity run on **Going Merry** to keep Thriller Bark uncrowded.
- **Thriller Bark** hosts the control plane: Headscale, Komodo Core, Caddy edge, the observability stack and the backup orchestrator.
- **The Thousand Sunny** runs the full media/arr stack as Ultra.cc-managed apps. Outside Komodo; this repo only versions helper scripts and docs.
- **Den Den Mushi** stays independent (HAOS-managed); it joins the mesh and its backups are folded in later.

## Cross-cutting architecture

### Mesh — Headscale

- **Headscale** (self-hosted Tailscale control plane) on Thriller Bark, exposed publicly through Caddy.
- Every node joins as a Tailscale client; userspace mode on Going Merry (old kernel) and The Thousand Sunny (no root).
- All inter-node traffic — Komodo, metrics, logs, backups, reverse-proxying — goes over the mesh.

### Ingress — Caddy

**Caddy** is the single public edge, on **Thriller Bark**. It terminates TLS and reverse-proxies to backends over the mesh.

- Wildcard certs via **Let's Encrypt DNS-01 using the Cloudflare DNS API**.
- **Cloudflare is DNS-only** (grey cloud).
- Public ports 80/443 open **only on Thriller Bark**.
- **The Thousand Sunny apps are out of scope for Caddy**: Plex and the arr services keep Ultra.cc's own Nginx and their existing remote-access path.
- Config is a static `Caddyfile` in the repo.

### Secrets — SOPS + age

Secrets are committed to Git **encrypted** with `age`, decrypted at deploy time.

- The only out-of-band artifact in the entire infra is **one age private key**, kept in a password manager.
- Disaster recovery: clone repo + drop in age key → everything decrypts → Komodo redeploys.
- `.sops.yaml` at repo root defines age recipients and which files are encrypted (`*.env`, `secrets.*`). Encrypted env files are decrypted into place by a deploy step / Komodo action.

### Deploy — Komodo (GitOps)

- **Komodo Core** on Thriller Bark; **Periphery agents** on Thriller Bark and Going Merry, reached over the mesh.
- Deploys Compose stacks straight from this repo via **Resource Sync** (TOML under `komodo/`), one web UI for all Docker nodes.
- Built-in image update polling replaces Diun.

### Backups — Backrest → restic → rclone → Proton Drive + Mega

- **Backrest** (restic web UI + scheduling) on Thriller Bark orchestrates backups.
- **restic** encrypts client-side, then ships via **rclone** remotes:
  - **Proton Drive** (large space) — default target for everything backed up.
  - **Mega.nz** (50 GB) — replicated second copy of the critical subset only (finances, DB dumps, workflow exports, encrypted secrets material).
- Neither provider sees plaintext.
- **Media is not backed up** (re-acquirable). Backups cover config volumes, databases, metadata, photos/location, finances.

### Observability — Grafana + VictoriaMetrics + Loki + Alloy

Central stack on **Thriller Bark**:

- **VictoriaMetrics** — metrics store.
- **Loki** — log aggregation.
- **Grafana** — dashboards.
- **Grafana Alloy** — one collector per node: scrapes container + host metrics, tails logs, ships to VM/Loki over the mesh. Userspace binary on nodes without Docker where feasible.

## Repo layout

```txt
the-sea/
├── README.md
├── .sops.yaml                      # age recipients + encryption rules
├── docs/
│   ├── runbooks/                   # disaster-recovery, add-a-node, add-a-service, restore-test
│   └── specs/                      # design specs (this file, future.md)
├── komodo/                         # Komodo resource-sync TOML: stacks → servers
├── thriller-bark/                  # Docker host (Oracle) — control plane
│   ├── headscale/
│   ├── caddy/
│   ├── komodo/
│   ├── observability/              # grafana, victoriametrics, loki, alloy
│   ├── backrest/
│   └── <app>/                      # compose.yaml + sops-encrypted env
├── going-merry/                    # Docker host (OpenVZ) — light/legacy
│   └── <app>/                      # compose.yaml + sops-encrypted env
├── thethousandsunny/               # Ultra.cc managed apps — scripts + docs only
│   └── scripts/                    # start_all / stop_all / upgrade_all
├── dendenmushi/                    # Home Assistant — backup config + docs
└── scripts/                        # cross-node helpers: bootstrap-node, sops wrappers, restore-test
```

Per-ship top-level dirs map 1:1 onto Komodo server targets. Cross-cutting concerns (`komodo/`, `docs/`, `scripts/`, `.sops.yaml`) live at root.

## Service distribution

### Control plane

| Service                          | Node                       |
| -------------------------------- | -------------------------- |
| Headscale                        | Thriller Bark              |
| Caddy                            | Thriller Bark              |
| Komodo Core                      | Thriller Bark              |
| Komodo Periphery                 | Thriller Bark, Going Merry |
| Backrest                         | Thriller Bark              |
| Grafana / VictoriaMetrics / Loki | Thriller Bark              |
| Alloy                            | Every node                 |

### Applications

| Service             | Node          | Comments                 |
| ------------------- | ------------- | ------------------------ |
| Actual Budget       | Thriller Bark | Sensitive                |
| Authentik           | Thriller Bark | Core, sensitive          |
| n8n                 | Thriller Bark | Performance requirements |
| Open-WebUI          | Thriller Bark | Critical                 |
| Wizarr              | Thriller Bark | Important                |
| bazarr2             | Going Merry   | Not critical             |
| Cleanuparr          | Going Merry   | Not critical             |
| Code-Server         | Going Merry   | Not critical             |
| Configarr           | Going Merry   | Runs infrequently        |
| Dawarich            | Going Merry   | Not critical             |
| Hedgedoc            | Going Merry   | Not critical             |
| Plex_Auto_Languages | Going Merry   | Not critical             |
| your_spotify        | Going Merry   | Not critical             |
