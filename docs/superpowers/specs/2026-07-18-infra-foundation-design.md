# The Sea — Infrastructure Foundation Design

**Date:** 2026-07-18
**Status:** Approved (foundation scope)
**Repo:** `the-sea`

## 1. Context

Self-hosted homelab currently living as per-app Docker Compose folders on a
single ageing OpenVZ VPS. It has since grown to four machines across three
providers plus a Raspberry Pi. This is a program to rebuild everything for
reproducibility, backups, and unified management across all nodes.

This document specs the **foundation** only — the cross-cutting layers every
later service migration depends on. Individual app migrations are separate
sub-projects (see §9).

## 2. Goals / Non-goals

**Goals**
- **Reproducible:** everything defined in Git; a dead server rebuilds from the
  repo + one secret key. Some downtime during a rebuild is acceptable.
- **Backed up:** automated, encrypted, tested backups with a known restore path.
- **Unified management:** one workflow/dashboard to deploy across all Docker nodes.
- **Observability:** metrics + logs surfaced centrally.

**Non-goals (explicitly out of scope)**
- **Live failover / HA.** No clustering, no shared/replicated storage, no
  automatic service migration. This decision removes the largest source of
  complexity and is deliberate.
- **Kubernetes / k3s / any orchestrator.** The OpenVZ node's old kernel can't
  run it well and a 4-node homelab doesn't need it.

## 3. Nodes

| Ship name | Machine | Role | Container runtime |
|-----------|---------|------|-------------------|
| **Thriller Bark** | Oracle Cloud ARM (4 vCPU / 24 GB) | Workhorse + control plane | Docker + Komodo agent |
| **Going Merry** | OpenVZ VPS (old kernel) | Legacy/light Docker node | Docker + Komodo agent |
| **The Thousand Sunny** | Ultra.cc box (no sudo, no Docker) | Media + download node | Ultra.cc managed `app-*` services (no Docker) |
| **Den Den Mushi** | Raspberry Pi | Home Assistant | HAOS (managed, not Komodo) |

**Placement rules**
- Main services run on **Thriller Bark** (modern, reliable). Only services that
  specifically need it — or that Thriller Bark can't run — land on **Going Merry**.
- **Thriller Bark** hosts the control plane: Komodo Core, Caddy edge, the
  observability stack, and the backup orchestrator.
- **The Thousand Sunny** runs the full media/arr stack as Ultra.cc-managed apps
  (plex, radarr×2, sonarr×2, prowlarr, qbittorrent, bazarr, overseerr, tautulli,
  syncthing, etc.). It is **outside** Docker/Komodo — the repo only versions its
  helper scripts and documents it. The media library lives here.
- **Den Den Mushi** stays independent (HAOS-managed); it joins the mesh and its
  backups are folded in later.

## 4. Cross-cutting architecture

### 4.1 Networking — Tailscale mesh
All four nodes join one Tailscale tailnet. Private, encrypted, name-addressable,
**zero open admin ports**. SSH, dashboards, backend-to-backend, and Alloy→Grafana
traffic all ride the tailnet.

- **The Thousand Sunny (no sudo)** and **Going Merry (OpenVZ, maybe no
  `/dev/net/tun`)** run Tailscale in **userspace mode**
  (`tailscaled --tun=userspace-networking`) — no root required.
- **Den Den Mushi** joins via the Home Assistant Tailscale add-on.

### 4.2 Ingress — Caddy (self-hosted edge)
**Caddy** is the single public edge, on **Thriller Bark**. It terminates TLS and
reverse-proxies to backends over the tailnet.

- Certificates via **Let's Encrypt DNS-01 challenge using the Cloudflare DNS
  API** → wildcard certs, no need to expose which services exist, no inbound
  port 80 required.
- **Cloudflare is DNS-only** (grey cloud). It resolves names; it never sees or
  serves traffic. No delegation of serving.
- Public ports 80/443 are open **only on Thriller Bark**.
- **Plex is the exception** — it keeps its own Ultra.cc/Plex remote-access path,
  not Caddy.
- Replaces **Nginx Proxy Manager**. Config is a static `Caddyfile` in the repo.

### 4.3 Secrets — SOPS + age
Secrets are committed to Git **encrypted** with `age`, decrypted at deploy time.

- The only out-of-band artifact in the entire infra is **one age private key**,
  kept in a password manager.
- Disaster recovery: clone repo + drop in age key → everything decrypts →
  Komodo redeploys.
- `.sops.yaml` at repo root defines age recipients and which files are encrypted
  (`*.env`, `secrets.*`). Encrypted env files are named consistently and
  decrypted into place by a deploy step / Komodo action.

### 4.4 Deploy — Komodo (GitOps)
**Komodo** replaces **Portainer + Diun**.

- **Komodo Core** on Thriller Bark; **Periphery agents** on Thriller Bark and
  Going Merry, reached over the tailnet.
- Deploys Compose stacks straight from this repo via **Resource Sync** (declared
  in TOML under `komodo/`), one web UI for all Docker nodes.
- Built-in image update polling replaces Diun.

### 4.5 Backups — Backrest → restic → rclone → Proton Drive + Mega
- **Backrest** (restic web UI + scheduling) on Thriller Bark orchestrates backups.
- **restic** encrypts client-side, then ships via **rclone** remotes:
  - **Proton Drive** (large space) — the **bulk** target. rclone's Proton backend
    is community-maintained and can break on Proton API changes; acceptable for
    bulk.
  - **Mega.nz** (50 GB, mature rclone backend) — a **second copy of the most
    critical small data** (finances, DB dumps, workflow exports, encrypted
    secrets material).
- Neither provider sees plaintext (restic encrypts before upload).
- **Media is not backed up** (re-acquirable). Backups cover config volumes,
  databases, metadata, photos/location, finances.
- Nodes without Docker (Sunny) can run the restic + rclone **binaries** in
  userspace if their data needs backing up.

### 4.6 Observability — Grafana + VictoriaMetrics + Loki + Alloy
Central stack on **Thriller Bark**:
- **VictoriaMetrics** — metrics store (lighter than Prometheus, kinder to the
  small nodes).
- **Loki** — log aggregation.
- **Grafana** — dashboards.
- **Grafana Alloy** — one collector agent per node: scrapes container + host
  metrics and tails logs, shipping to VM/Loki over the tailnet. Runs as a
  userspace binary on nodes without Docker where feasible.
- **Traces deferred.** Tempo/OTel add only when self-instrumented apps exist;
  third-party self-hosted apps don't emit traces, so the components would sit
  empty.

## 5. Repo layout

```
the-sea/
├── README.md
├── .sops.yaml                      # age recipients + encryption rules
├── docs/
│   ├── architecture.md             # living overview (this design, condensed)
│   ├── runbooks/                   # disaster-recovery, add-a-node, add-a-service, restore-test
│   └── superpowers/specs/          # design specs (this file)
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

Per-ship top-level dirs map 1:1 onto Komodo server targets. Cross-cutting
concerns (`komodo/`, `docs/`, `scripts/`, `.sops.yaml`) live at root.

## 6. Tool changes

- **Drop:** Nginx Proxy Manager (→ Caddy), Portainer + Diun (→ Komodo).
- **Add:** Tailscale, Caddy, SOPS/age, Komodo, Backrest (+restic/rclone),
  Grafana + VictoriaMetrics + Loki + Alloy.
- **Keep as-is:** Authentik, the arr/media stack (on Sunny), actualbudget,
  hedgedoc, dawarich, open-webui, n8n, your_spotify, code-server, Home Assistant,
  the Minecraft server.

## 7. Migration of existing configs
Existing compose folders move under their target ship dir and are adapted:
- Replace the external `revproxy` network with Caddy-over-tailnet reverse
  proxying (drop the `revproxy` network from compose files).
- Convert `.env` files to SOPS-encrypted env, remove `.env.example` plaintext
  secrets from history going forward.

## 8. Foundation acceptance criteria
The foundation is "done" when:
1. All four nodes are on the tailnet and reachable by name.
2. Komodo Core + agents are up; a **pilot service deploys from Git** to a node.
3. Caddy serves that pilot service publicly with a valid wildcard cert, CF DNS-only.
4. A secret is stored via SOPS and consumed by the pilot deploy.
5. Backrest runs a backup of the pilot's data to Proton **and** Mega, and a
   **restore-test** recovers it.
6. Grafana shows metrics + logs from at least Thriller Bark and Going Merry.

## 9. Program decomposition (sub-projects, in order)
1. **Foundation** ← this spec (mesh, secrets, Komodo, Caddy, backups, observability, pilot).
2. Migrate stateless web apps (hedgedoc, your_spotify, open-webui, code-server…).
3. Migrate stateful apps (Authentik, actualbudget, dawarich) with restore drills.
4. Media/arr sub-project — wire Going Merry's Docker arr bits to Sunny over the
   tailnet; document Sunny's managed apps.
5. Fold in Home Assistant (Den Den Mushi) backups + mesh.

## 10. Open questions (for later sub-projects, not the foundation)
- Exactly which arr services must run on Going Merry vs. Sunny, and how they
  reach the media library over the tailnet.
- Whether any optional new apps get added (deferred; YAGNI until wanted).
- RPi name: **Den Den Mushi** proposed (alts: Mini Merry, Coby) — confirm.
