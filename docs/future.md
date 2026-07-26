# The Sea — Future / Deferred

Not part of the foundation. Revisit after the foundation is running.

## Deferred decisions

- **Sunny backups** — decide whether app configs/DBs on Ultra.cc are worth backing up (restic + rclone binaries in userspace) or nothing at all.
- **Baratie** — join the mesh; fold HAOS backups into Backrest.
- **Security — what the 2026-07 reviews left open.** Both nodes were reviewed (GM, then
  TB on 2026-07-25); the perimeter was found sound on both and everything actionable was
  fixed or dispatched into the runbooks. Still open, in rough priority order:
  - ~~**Narrow the `your_spotify` `/api/*` edge bypass**~~ — planned, see
    `docs/plans/2026-07-26-your-spotify-api-bypass.md`. Until it lands,
    `allowRegistrations: false` is the only thing stopping public account creation and
    **must stay off**.
  - ~~**Caddy admin API**~~ — planned, see `docs/plans/2026-07-25-caddy-admin-off.md`.
  - **GM container least-privilege is capped by the OpenVZ kernel** — no AppArmor, no
    userns-remap, seccomp active. Accepted, not fixable there.
  - **`profilarr` OIDC client has `require_pkce: false`** (deliberate, confidential
    client, `client_secret_post`); revisit if Profilarr gains support.
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
- **When the first n8n workflow calls LiteLLM, set a session header.** Nothing does this
  automatically. Open-WebUI gets session grouping for free because it sends the chat id;
  an n8n HTTP Request node must set `x-litellm-session-id` itself. The value has to match
  `^[a-zA-Z0-9_\-]{8,}$` — a slash or colon and LiteLLM silently ignores it, no error.
  **Decide once, because it cannot be fixed retroactively in the logs:** is a session one
  execution (`{{ $execution.id }}`) or one logical conversation spanning executions?
  Tracing is already wired — `N8N_OTEL_TRACES_INJECT_OUTBOUND=true` is set, so the calls
  will join one trace — but that has never been exercised by a real workflow either.
- **n8n automations for Actual Budget** — auto-sync, auto-categorization, rule
  creation, Telegram bot.
- **n8n automations for Radarr/Sonarr** — on Radarr, switch anime to the right quality
  profile; on Sonarr/Seerr, route anime requests to the correct Sonarr instance.
- Explore s3drive as an alternative to reach Proton Drive. Useful for S3-compatible access too.

## Tool wishlist

Concrete candidate in parens where decided. Anything with a live plan is in
`docs/plans/`, not here. LangFuse dropped — Grafana/Loki covers LLM logging.

Syncthing's "dropped for now" entry is gone — the exception it was waiting on was
[made deliberately](decisions/2026-07-26-syncthing-public-port.md), and it has a plan.
Karakeep, Wallos and Forgejo likewise.

- **Forgejo Actions runner** — deferred out of the Forgejo plan, not dropped. It needs a
  registration token from a running instance, so it can never share that first deploy.
  When it lands it goes on **TB** (GM's single-thread CPU would make builds crawl) and it
  gets the Docker socket, which on GM would mean no AppArmor and no userns-remap.
- **Obsidian web editor** — skipped for now. Syncthing already puts the vault on every
  machine that matters, so browser editing is a want, not a gap. If it comes back:
  SilverBullet (small, multi-arch, plain markdown, but *not* Obsidian — no plugins, no
  Dataview) pointed at the vault dir, which pins it to **TB** beside Syncthing.
  obsidian-remote gives real Obsidian at the cost of a whole VNC desktop.

Six candidates were [dropped in one pass](decisions/2026-07-26-wishlist-tools-dropped.md)
— configarr, huntarr, hedgedoc, it-tools, stirling-pdf, coolify — and maintainerr moved to
Sunny. What's left:

- ~~PDF management (Paperless-ngx)~~ — planned, see
  `docs/plans/2026-07-26-paperless-ngx.md`. Blocked on Syncthing.
- **Habit tracker — tool choice reopened.** Beaverhabits was
  [chosen on 2026-07-25](decisions/2026-07-25-beaverhabits-not-habitica.md) and is no
  longer the answer; nothing replaces it yet. Pick the tool before writing a plan.
- Static site — too underspecified to plan. Decide what the site *is* first.
- Open Terminal for Open WebUI — needs Open-WebUI live first.
- **Proton Mail Bridge** — the fleet has no SMTP at all. Authelia writes password resets
  and 2FA enrolment to `/config/notification.txt` (`notifier.filesystem`), which is why
  those flows are hand-read today; Grafana alerting goes to Telegram and doesn't need it.
  A headless bridge on **TB** beside Authelia would turn the file notifier into real mail.
  **Decide first:** whether Authelia alone justifies it, and whether the bridge's
  unattended-login problem (it wants an interactive `login` per restart, and holds a
  full-mailbox credential) is acceptable versus a plain SMTP relay from another provider.
