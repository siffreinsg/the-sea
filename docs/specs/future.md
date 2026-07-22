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

- PDF management
- File converter (IT-Tools or OmniTools)
- GenAI platform
- Syncthing with Proton Drive support
- Obsidian webapp alternative or interface
- Local git with CI/CD pipelines
- Habitica / habit tracker
- Static site
- Profilarr
- Langfuse
