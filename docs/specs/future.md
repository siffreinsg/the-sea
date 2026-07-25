# The Sea — Future / Deferred

Not part of the foundation. Revisit after the foundation is running.

## Deferred decisions

- **Sunny backups** — decide whether app configs/DBs on Ultra.cc are worth backing up (restic + rclone binaries in userspace) or nothing at all.
- **Baratie** — join the mesh; fold HAOS backups into Backrest.
- **Security audit (TB + GM)** — after Plan 2/3 land: close unnecessary open ports, review what's exposed beyond the Caddy edge, harden both nodes (firewall rules, unattended-upgrades, SSH config, container least-privilege, etc).
- **Sunny / Baratie collectors** — a userspace Alloy binary on Sunny, HAOS
  Prometheus add-on or mesh scrape for Baratie; both push to VM/Loki on **GM**
  (`100.64.0.1`). **This is the only thing that would justify putting Sunny on the
  mesh** — VM and Loki bind the mesh IP and have no public route, so Sunny can't reach
  them today. Weigh a userspace Tailscale client on Sunny against simply not
  collecting from it.

## Deferred plans

- **Move Home Assistant off Baratie into the cloud** — HA **Container** on **GM**, not
  HAOS. Baratie stays, reduced to a radio/LAN bridge: fresh RPi OS Lite, Tailscale
  subnet router advertising the LAN, Komodo Periphery. On the Freebox, the port forward
  goes away — nothing inbound to the LAN.
  - **Already decided, don't relitigate:** occasional outages are acceptable, and the
    Pi remaining a single point of failure is acceptable.
  - **Still to do before this is plannable:** an exhaustive inventory of what has to
    migrate — automations, dashboards, config, every integration, and each manual
    modification made to the running instance.
- **n8n automations for Actual Budget** — auto-sync, auto-categorization, rule
  creation, Telegram bot.
- **n8n automations for Radarr/Sonarr** — on Radarr, switch anime to the right quality
  profile; on Sonarr/Seerr, route anime requests to the correct Sonarr instance.

## Tool wishlist

Concrete candidate in parens where decided. Anything with a live plan is in
`docs/plans/`, not here. LangFuse dropped — Grafana/Loki covers LLM logging.

- **Syncthing** (Obsidian vault sync) — **dropped for now**, not abandoned. It needs
  its peers to reach port 22000, but GM services bind `100.64.0.1` (mesh-only) and only
  TB opens public ports. Revisit when every sync peer is a Tailscale client, or decide
  deliberately to make an exception to the bind rule.

- PDF management (Paperless-ngx) + PDF ops (Stirling-PDF)
- File converter (IT-Tools — single static container, easy first)
- Obsidian web editor (SilverBullet, pointed at the Syncthing vault folder)
- Local git with CI/CD (Forgejo + Actions runner)
- Habit tracker — **research pending**: Habitica (heavy, Mongo, RPG gamification) vs Beaverhabits (tiny, tracking only)
- Static site
- Karakeep — bookmarks / read-it-later with AI tagging (synergy with LiteLLM)
- Wallos (subscription tracker, complements Actual)
- Open Terminal for Open WebUI
- Coolify
