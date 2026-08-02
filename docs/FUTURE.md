# Future

Ideas and deferred questions, not on deck. Anything with a named phase and domain lives in
[TODO.md](TODO.md); anything with a *how* is a plan in [plans/](plans/).

## Deferred decisions

- Rework the Claude Code setup — Superpowers burns all the tokens. Rewrite the skills by hand.
- **Sunny backups** — decide whether app configs/DBs on Ultra.cc are worth backing up (restic + rclone binaries in userspace) or nothing at all.
- **Baratie** — join the mesh; fold HAOS backups into Backrest.
- **Security, accepted rather than fixed:** GM container least-privilege is capped by the
  OpenVZ kernel (no AppArmor, no userns-remap, seccomp active); `profilarr`'s OIDC client
  has `require_pkce: false` (deliberate, confidential client, `client_secret_post`) —
  revisit if Profilarr gains support.
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
- **Wire n8n to LiteLLM — it isn't yet.** This is the reason LiteLLM exists; don't let n8n
  hold provider keys directly. Give it its own virtual key, and note the URL: **not**
  `http://127.0.0.1:4000/v1`. n8n is a bridged container, so that is its own loopback (the
  same bug already fixed for Open-WebUI). n8n is deliberately isolated on `n8n-edge`
  (shared only with Caddy — it runs user-supplied code) and **must not** join
  `ai-backends` to reach LiteLLM directly, that undoes the isolation and hands it
  open-webui and tika too. Go through the public edge instead: `https://ai.siffreinsigy.me/v1`.
- **When the first n8n workflow calls LiteLLM, set a session header.** Nothing does this
  automatically. Open-WebUI gets session grouping for free because it sends the chat id;
  an n8n HTTP Request node must set `x-litellm-session-id` itself. The value has to match
  `^[a-zA-Z0-9_\-]{8,}$` — a slash or colon and LiteLLM silently ignores it, no error.
  **Decide once, because it cannot be fixed retroactively in the logs:** is a session one
  execution (`{{ $execution.id }}`) or one logical conversation spanning executions?
  Tracing is already wired — `N8N_OTEL_TRACES_INJECT_OUTBOUND=true` is set, so the calls
  will join one trace — but that has never been exercised by a real workflow either.
- **Grafana access to the conversation archive.** 180 days of conversations sit in
  `LiteLLM_SpendLogs`; Tempo only covers 14. Reading them from Grafana needs a mesh-published
  port on a Postgres that deliberately has none, plus a read-only role. Security decision,
  not a slip-in.
- Explore s3drive as an alternative to reach Proton Drive. Useful for S3-compatible access too.

## Automations

Mechanism (n8n, Komodo, systemd, a script) is per-item, decided when each is planned.

- **Actual Budget** — auto-sync, auto-categorization, rule creation, Telegram bot.
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
- Detect conflicting files on syncthing

## Tool wishlist

Concrete candidate in parens where decided. Anything with a live plan is in `docs/plans/`,
not here; anything dropped is in
[one decision](ADR/2026-07-26-wishlist-tools-dropped.md) — except LangFuse, dropped
because Grafana/Loki already covers LLM logging.

- **Forgejo Actions runner** — deferred out of the Forgejo plan, not dropped. It needs a
  registration token from a running instance, so it can never share that first deploy.
  When it lands it goes on **TB** (GM's single-thread CPU would make builds crawl) and it
  gets the Docker socket, which on GM would mean no AppArmor and no userns-remap.
- **Obsidian web editor** — skipped for now. Syncthing already puts the vault on every
  machine that matters, so browser editing is a want, not a gap. If it comes back:
  SilverBullet (small, multi-arch, plain markdown, but *not* Obsidian — no plugins, no
  Dataview) pointed at the vault dir, which pins it to **TB** beside Syncthing.
  obsidian-remote gives real Obsidian at the cost of a whole VNC desktop.

- **Habit tracker — no tool chosen.** Beaverhabits is out
  ([the decision, reopened](ADR/2026-07-25-beaverhabits-not-habitica.md)) and nothing
  replaces it. Pick the tool before writing a plan.
- Static site — too underspecified to plan. Decide what the site *is* first.
- Open Terminal for Open WebUI — needs Open-WebUI live first.
- **Proton Mail Bridge** — the fleet has no SMTP at all. Authelia writes password resets
  and 2FA enrolment to `/config/notification.txt` (`notifier.filesystem`), which is why
  those flows are hand-read today; Grafana alerting goes to Telegram and doesn't need it.
  A headless bridge on **TB** beside Authelia would turn the file notifier into real mail.
  **Decide first:** whether Authelia alone justifies it, and whether the bridge's
  unattended-login problem (it wants an interactive `login` per restart, and holds a
  full-mailbox credential) is acceptable versus a plain SMTP relay from another provider.

## AI platform, deferred from the config review

Landed in `docs/plans/2026-07-26-ai-platform-config-review.md`; these outlive it.

- **[LangSearch](https://langsearch.com/) as a search provider, maybe as a reranker.**
  Routing web search through LiteLLM rather than pointing Open-WebUI at one engine means
  several providers can sit side by side, so SearXNG and a hosted API can be compared on
  the same queries instead of swapped blind. Would also drop the scraping-reputation
  problem SearXNG carries. Their reranker is the hosted option
  [rejected on data exposure](ADR/2026-07-28-no-reranking.md); revisiting it means
  superseding that ADR, not editing it.
- **Benchmark the chunking choice.** `RAG_TEXT_SPLITTER=token`, 800/100, markdown
  header pre-pass — picked on reasoning, never measured. Re-chunking costs a full
  re-embed at Scaleway's rate but no schema change, so this is revisable, unlike the
  3584 vector dimension. Needs a real corpus and a retrieval-quality comparison first.
- **tiktoken downloads at runtime on `-slim`.** `USE_SLIM=true` skips baking the
  `cl100k_base` encoding, so the first document ingest fetches it from OpenAI's CDN and
  caches into `TIKTOKEN_CACHE_DIR` inside the volume. Fine here; **a blocker for an
  air-gapped company deployment**, which would have to pre-seed the cache or use the
  character splitter.
- **Free-tier exhaustion is handled by the 429, not by a rate limit.** Mistral's free
  tier moves with global platform load, so no static `rpm`/`tpm` can track it. Fallback
  to paid Scaleway is driven by `retry_policy.RateLimitErrorRetries: 1`. Because
  `task-cheap` is a single-deployment group, `cooldown_time` does not apply
  (`cooldown_handlers.py:178`) — every call during exhaustion pays one retry before
  failing over. If that becomes noticeable, add a second deployment to the group to
  re-enable cooldown rather than inventing a limit.
