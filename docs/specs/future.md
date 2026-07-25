# The Sea — Future / Deferred

Not part of the foundation. Revisit after the foundation is running.

## Deferred decisions

- **Sunny backups** — decide whether app configs/DBs on Ultra.cc are worth backing up (restic + rclone binaries in userspace) or nothing at all.
- **Baratie** — join the mesh; fold HAOS backups into Backrest.
- **Security — what the 2026-07 reviews left open.** Both nodes were reviewed (GM, then
  TB on 2026-07-25); the perimeter was found sound on both and everything actionable was
  fixed or dispatched into the runbooks. Still open, in rough priority order:
  - **Containers reach the tailnet** (TB, see `operations.md`). Short fix:
    `iptables -I DOCKER-USER -s 172.16.0.0/12 -d 100.64.0.0/10 -j REJECT`, persisted via
    `iptables-persistent` — the chain is empty today and no bridged container needs mesh
    access. Durable fix: a Headscale ACL policy, which also covers future mesh nodes.
  - **Decide whether `komodo` becomes a synced stack.** Bootstrap-order concerns are
    real, but the current arrangement gets the discipline of neither approach.
  - **Rotate four `*arr` API keys** that sat in world-readable legacy `.env` files on GM.
    The files are gone; the keys authenticate to Sunny, which is public. Check which
    live stacks consume them first.
  - **Narrow the `your_spotify` `/api/*` edge bypass** to the paths that genuinely can't
    carry a redirect (OAuth callback + the SPA's XHR prefix). Today the whole API is
    unauthenticated at the edge and `/api/global/preferences` is public; only
    `allowRegistrations: false` stops public account creation — **it must stay off**.
  - **Caddy admin API** — dedicated loopback metrics site, then `admin off`.
  - **GM container least-privilege is capped by the OpenVZ kernel** — no AppArmor, no
    userns-remap, seccomp active. Accepted, not fixable there.
  - **`profilarr` OIDC client has `require_pkce: false`** (deliberate, confidential
    client, `client_secret_post`); revisit if Profilarr gains support.
  - **`going-merry/profilarr/compose.yaml` still pins `:latest`** — the pinning pass
    missed it. A parallel session owns that dir.
  - **Never scanned from off-network.** Hairpin NAT against `141.253.109.196` showed only
    80/443/22, and GM only 4747, but a source-conditional rule wouldn't show up that way.
    Also unread: the Oracle VCN security list, so it's unknown which layer closes what.
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
