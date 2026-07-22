# The Sea — Future / Deferred

Not part of the foundation. Revisit after the foundation is running.

## Deferred decisions

- **Sunny backups** — decide whether app configs/DBs on Ultra.cc are worth backing up (restic + rclone binaries in userspace) or nothing at all.
- **Den Den Mushi** — join the mesh; fold HAOS backups into Backrest.
- **Security audit (TB + GM)** — after Plan 2/3 land: close unnecessary open ports, review what's exposed beyond the Caddy edge, harden both nodes (firewall rules, unattended-upgrades, SSH config, container least-privilege, etc).
- **Sunny / Den Den Mushi collectors** — userspace Alloy binary on Sunny, HAOS Prometheus
  add-on or mesh scrape for DDM; both push to VM/Loki on TB (100.64.0.2).
- **Alerting** — Grafana alert rules (disk full, backup plan failed, node down) once
  baseline dashboards have run for a while.

## Tool wishlist

Concrete candidate in parens where decided. (Open-WebUI+LiteLLM, Profilarr, Syncthing
now live in `docs/plans/2026-07-22-batch-1-apps.md`. LangFuse dropped — Grafana/Loki
covers LLM logging.)

- PDF management (Paperless-ngx) + PDF ops (Stirling-PDF)
- File converter (IT-Tools — single static container, easy first)
- Obsidian web editor (SilverBullet, pointed at the Syncthing vault folder)
- Local git with CI/CD (Forgejo + Actions runner)
- Habit tracker — **research pending**: Habitica (heavy, Mongo, RPG gamification) vs Beaverhabits (tiny, tracking only)
- Static site
- Authelia passkey/WebAuthn (add after TOTP baseline; OIDC apps inherit it)
- Alerting → Telegram bot (n8n/Grafana), see also `future.md` deferred alerting
- Karakeep — bookmarks / read-it-later with AI tagging (synergy with LiteLLM)
- Wallos (subscription tracker, complements Actual)
- Open Terminal for Open WebUI
