# 🌊 The Sea

Infrastructure-as-code for a self-hosted homelab across four nodes.

| Ship                   | Machine                 | Role                                                              |
| ---------------------- | ----------------------- | ----------------------------------------------------------------- |
| **Thriller Bark**      | Oracle Cloud ARM (4/24) | Workhorse + control plane (Komodo, Caddy, observability, backups) |
| **Going Merry**        | Omgserv OpenVZ VPS      | Light/legacy Docker node                                          |
| **The Thousand Sunny** | Ultra.cc box            | Media + downloads (Ultra.cc-managed apps, no Docker)              |
| **Baratie**            | Raspberry Pi            | Home Assistant (HAOS)                                             |

**Den Den Mushi** is the Telegram alert bot, not a node — the transponder snail
carries messages, so Grafana's alerts speak through it.

## Stack

- **Networking:** Headscale mesh — Thriller Bark + Going Merry only; Sunny is reached over its public HTTPS/SSH
- **Ingress:** Caddy on Thriller Bark, Let's Encrypt via Cloudflare DNS-01 (CF = DNS only)
- **Secrets:** SOPS + age (encrypted in-repo)
- **Deploy:** Komodo GitOps from this repo
- **Backups:** Backrest → restic → rclone → Proton Drive (bulk) + Mega (critical mirror)
- **Observability:** Grafana + VictoriaMetrics + Loki + Alloy

## Layout

Top-level dirs are per-ship (map onto Komodo server targets). Cross-cutting concerns live at root: `komodo/`, `docs/`, `.sops.yaml`.

See [`docs/specs/foundation-design.md`](docs/specs/foundation-design.md) for the full foundation design and [`docs/specs/future.md`](docs/specs/future.md) for deferred items.
