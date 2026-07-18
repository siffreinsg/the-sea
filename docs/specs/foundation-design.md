# The Sea — Infrastructure Foundation Design

Manage my homelab like a king.

The goals are to have a reproducible, back-up and unified homelab. Everything is defined in Git, with one dashboard to deploy across all Docker.

Sadly, Kubernetes is not compatible with the setup so we have to go a different route.

> This document specs the **foundation** only — the cross-cutting layers every later service migration depends on. Individual app migrations are separate sub-projects (see §9).

## Nodes

| Ship name              | Machine                           | Role                      | Container runtime                 |
| ---------------------- | --------------------------------- | ------------------------- | --------------------------------- |
| **Thriller Bark**      | Oracle Cloud ARM (4 vCPU / 24 GB) | Workhorse + control plane | Docker + Komodo agent             |
| **Going Merry**        | Omgserv OpenVZ VPS (old kernel)   | Legacy/light Docker node  | Docker + Komodo agent             |
| **The Thousand Sunny** | Ultra.cc box (no sudo, no Docker) | Media + download node     | Ultra.cc managed `app-*` services |
| **Den Den Mushi**      | Raspberry Pi                      | Home Assistant            | HAOS (managed, not Komodo)        |

- Major services run on **Thriller Bark** (modern, reliable). To avoid crowding the server, services without performance requirements or low-sensitivity should run on **Going Merry** instead.
- **Thriller Bark** hosts the control plane: Komodo Core, Caddy edge, the observability stack and the backup orchestrator.
- **The Thousand Sunny** runs the full media/arr stack as Ultra.cc-managed apps. It is outside Komodo, this repo will only versions helper scripts and documentations.
- **Den Den Mushi** stays independent (HAOS-managed); it joins the mesh and its backups are folded in later.

## Cross-cutting architecture

TBD: Headscale maybe

### Ingress — Caddy (self-hosted edge)

**Caddy** is the single public edge, on **Thriller Bark**. It terminates TLS and reverse-proxies to backends over the mesh network.

- Certificates via **Let's Encrypt DNS-01 challenge using the Cloudflare DNS API** with wildcard certs.
- **Cloudflare is DNS-only** (grey cloud).
- Public ports 80/443 are open **only on Thriller Bark**.
- **The Thousand Sunny apps are out of scope for Caddy**: Plex and the arr services on Ultra.cc are fronted by Ultra.cc's **own Nginx** and keep their existing remote-access path. Caddy never touches them.
- Config is a static `Caddyfile` in the repo.

### Secrets — SOPS + age

Secrets are committed to Git **encrypted** with `age`, decrypted at deploy time.

- The only out-of-band artifact in the entire infra is **one age private key**, kept in a password manager.
- Disaster recovery: clone repo + drop in age key → everything decrypts → Komodo redeploys.
- `.sops.yaml` at repo root defines age recipients and which files are encrypted (`*.env`, `secrets.*`). Encrypted env files are named consistently and decrypted into place by a deploy step / Komodo action.

### Deploy — Komodo (GitOps)

- **Komodo Core** on Thriller Bark; **Periphery agents** on Thriller Bark and Going Merry, reached over the mesh network.
- Deploys Compose stacks straight from this repo via **Resource Sync** (declared in TOML under `komodo/`), one web UI for all Docker nodes.
- Built-in image update polling replaces Diun.

### 4.5 Backups — Backrest → restic → rclone → Proton Drive + Mega

- **Backrest** (restic web UI + scheduling) on Thriller Bark orchestrates backups.
- **restic** encrypts client-side, then ships via **rclone** remotes:
  - **Proton Drive** (large space) — the **default target for everything backed up**. rclone's Proton backend is community-maintained and can break on Proton API changes; acceptable for bulk.
  - **Mega.nz** (50 GB, mature rclone backend) — holds a **replicated second copy of the critical subset only** (finances, DB dumps, workflow exports, encrypted secrets material).
- Neither provider sees plaintext (restic encrypts before upload).
- **Media is not backed up** (re-acquirable). Backups cover config volumes, databases, metadata, photos/location, finances.
- Nodes without Docker (Sunny) can run the restic + rclone **binaries** in userspace if their data needs backing up.

### Observability — Grafana + VictoriaMetrics + Loki + Alloy

Central stack on **Thriller Bark**:

- **VictoriaMetrics** — metrics store (lighter than Prometheus, kinder to the small nodes).
- **Loki** — log aggregation.
- **Grafana** — dashboards.
- **Grafana Alloy** — one collector agent per node: scrapes container + host metrics and tails logs, shipping to VM/Loki over the WireGuard overlay. Runs as a userspace binary on nodes without Docker where feasible.

## Repo layout

```txt
the-sea/
├── README.md
├── .sops.yaml                      # age recipients + encryption rules
├── docs/
│   ├── architecture.md             # living overview (this design, condensed)
│   ├── runbooks/                   # disaster-recovery, add-a-node, add-a-service, restore-test
│   └── specs/                      # design specs (this file)
├── komodo/                         # Komodo resource-sync TOML: stacks → servers
├── thriller-bark/                  # Docker host (Oracle) — control plane
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

## Service Distribution

| Service             | Node          | Comments                 |
| ------------------- | ------------- | ------------------------ |
| Actual Budget       | Thriller Bark | Sensitive                |
| Authentik           | Thriller Bark | Core, sensitive          |
| Code-Server         | Going Merry   | Not critical             |
| Dawarich            | Going Merry   | Not critical             |
| Hedgedoc            | Going Merry   | Not critical             |
| n8n                 | Thriller Bark | Performance requirements |
| your_spotify        | Going Merry   | Not critical             |
| bazarr2             | TBD           | Depends on resources     |
| Cleanuparr          | Going Merry   | Not critical             |
| Configarr           | Going Merry   | Runs infrequently        |
| Plex_Auto_Languages | Going Merry   | Not critical             |
| Wizarr              | Thriller Bark | Important                |
| Open-WebUI          | Thriller Bark | Critical                 |
|                     |               |                          |

> The list needs to be updated with core services (networking, observability, control plane, ...)
> The list needs to splitted in two between applications and control plane
> Wishlist for new tools: pdf management, converter, it tools or OmniTools, genai platform, syncthing with proton drive support, obsidian webapp alternative or interface, local git with ci/cd pipelines, habitica, static site, habit tracker
/
## Open questions

- Exactly which apps must run on which node.
- Whether any new apps get added.
