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
- **Move Home Assistant off Baratie into the cloud** — **setup TBD.** The Pi is the
  one piece of infra whose failure needs physical presence to fix, and the only node
  outside the Komodo/GitOps model. Moving HA to TB or GM would fold it into the same
  deploy, backup and observability story as everything else.
  Open questions to settle before planning it:
  - **HAOS vs Container.** HAOS (the appliance OS, with add-ons and Supervisor) can't
    run as a Komodo stack; `home-assistant/home-assistant` in Docker can, but loses
    the add-on store and Supervisor backups. That trade is the whole decision.
  - **Local radios.** Anything Zigbee/Z-Wave/Bluetooth/Thread is bound to hardware in
    the house and cannot move. A cloud HA needs those bridged home (e.g. a Zigbee
    coordinator over IP), which turns the Pi into a radio bridge rather than
    retiring it.
  - **Local-network dependencies.** Discovery, mDNS, and any device speaking only to a
    LAN address stop working from a VPS unless the house joins the mesh.
  - **Latency and outage behaviour** — lights that stop responding when the home
    internet drops is a real regression, not a footnote.
  - Placement if it happens: **TB** (sensitive, always-on, and HA is not disk-heavy).

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
- Alerting → Telegram bot (n8n/Grafana), see also `future.md` deferred alerting
- Karakeep — bookmarks / read-it-later with AI tagging (synergy with LiteLLM)
- Wallos (subscription tracker, complements Actual)
- Open Terminal for Open WebUI
- Coolify
