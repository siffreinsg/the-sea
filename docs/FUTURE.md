# Future

Ideas and deferred questions, not on deck. Anything with a named phase and domain lives in
[TODO.md](TODO.md); anything with a *how* is a plan in [plans/](plans/).

## Project backlog

- Rework the Claude Code / Pi Agent setup
- Backup Sunny on Backrest
- Explore s3drive as an alternative to reach Proton Drive. Useful for S3-compatible access too.

## AI Platform

- Benchmark the chunking choice
- Include other free providers
- Grafana access to the full conversation archive: 180 days of conversations sit in `LiteLLM_SpendLogs`; Tempo only covers 14.
- Wire n8n to LiteLLM, with dedicated virtual key per workflows and a session id to match traces

## Tool Wishlist

- Paperless-ngx — document management.
- Forgejo — self-hosted git.
- Wallos — subscription tracker.
- Homepage — dashboard.
- Obsidian web alternative; maybe SilverBullet
- Habit tracker : maybe Beaverhabits, maybe another one
- Proton Mail Bridge for n8n automations

## Automations

Mechanism (n8n, Komodo, systemd, a script) is per-item, decided when each is planned.

- **Actual Budget** — auto-categorization, rule creation, Telegram bot. All three ride the
  `actual_api` sidecar ([ADR](ADR/2026-08-06-n8n-drives-actual-via-http-sidecar.md)).
- **Radarr/Sonarr** — on Radarr, switch anime to the right quality profile; on
  Sonarr/Seerr, route anime requests to the correct Sonarr instance.
- **Google Calendar event when I stay somewhere more than an hour** — needs a location
  source (Dawarich?) and a dwell-time trigger.
- Restart Plex and other *arr services on Sunny when unreachable — whether it upgrades,
  which services, filtering intelligence, escalation, and reporting are all still open.
- Run upgrades on Sunny regularly.
- Track traffic and disk quotas on Sunny.
- Sync Plex watch history with Trakt and TVTime.
- Weekly report of failing requests on Seerr.
- Detect stale Plex watchlist items across all users, add rules to remove via Maintainerr configs.
- Grafana dashboard derived from Tautulli, Plex and Seerr.
- Detect non-English content on Radarr/Sonarr, try dedicated profiles if the default fails.
- Fall back to a more permissive profile on Radarr/Sonarr for failing requests (e.g. 4K → HD).
- **On-demand dummy-file library** — dummy files for everything in Radarr/Sonarr; playing
  one triggers a real grab via the arr API, Tautulli webhook holds/resumes the stream
  until it lands. Deleted-then-requested-again items should fall back to a dummy too, so
  a repeat request loads fast instead of re-running the full request flow.
- Smart deletion by watch stats — when disk quota nears the limit, delete the
  least-recently-watched content via Tautulli's history + the arr delete API, skip
  anything Maintainerr is protecting.
- Missing-episode/corrupt-file health check — periodic scan for files Sonarr thinks it
  has that are 0-byte, unplayable, or missing from disk, auto-trigger a re-search.
