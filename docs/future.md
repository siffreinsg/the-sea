# The Sea — Future / Deferred

Not part of the foundation. Revisit after the foundation is running.

## Deferred decisions

- **Sunny backups** — decide whether app configs/DBs on Ultra.cc are worth backing up (restic + rclone binaries in userspace) or nothing at all.
- **Baratie** — join the mesh; fold HAOS backups into Backrest.
- **Security — open from the 2026-07 node reviews**, in rough priority order:
  - **Narrow the `your_spotify` `/api/*` edge bypass** (plan:
    `docs/plans/2026-07-26-your-spotify-api-bypass.md`). Until it lands,
    `allowRegistrations: false` is the only thing stopping public account creation and
    **must stay off**.
  - **Caddy admin API** is still open read/write on loopback (plan:
    `docs/plans/2026-07-25-caddy-admin-off.md`).
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
- **Wire n8n to LiteLLM — it isn't yet.** This is the reason LiteLLM exists; don't let n8n
  hold provider keys directly. Give it its own virtual key, and note the URL: **not**
  `http://127.0.0.1:4000/v1`. n8n is a bridged container, so that is its own loopback (the
  same bug already fixed for Open-WebUI). n8n has to **join `the-sea-internal`** — its
  compose has no `networks:` block today — and dial `http://litellm:4000/v1`. Same host, no
  mesh hop.
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
- **Narrow the duplicate alerting.** Grafana (Telegram) and Komodo (Discord) overlap, so
  some alerts arrive twice; neither side has been narrowed.

## Tool wishlist

Concrete candidate in parens where decided. Anything with a live plan is in `docs/plans/`,
not here; anything dropped is in
[one decision](decisions/2026-07-26-wishlist-tools-dropped.md) — except LangFuse, dropped
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

- PDF management (Paperless-ngx) — plan: `docs/plans/2026-07-26-paperless-ngx.md`.
  Blocked on Syncthing.
- **Habit tracker — no tool chosen.** Beaverhabits is out
  ([the decision, reopened](decisions/2026-07-25-beaverhabits-not-habitica.md)) and nothing
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

- **Benchmark the chunking choice.** `RAG_TEXT_SPLITTER=token`, 800/100, markdown
  header pre-pass — picked on reasoning, never measured. Re-chunking costs a full
  re-embed at Scaleway's rate but no schema change, so this is revisable, unlike the
  3584 vector dimension. Needs a real corpus and a retrieval-quality comparison first.
- **tiktoken downloads at runtime on `-slim`.** `USE_SLIM=true` skips baking the
  `cl100k_base` encoding, so the first document ingest fetches it from OpenAI's CDN and
  caches into `TIKTOKEN_CACHE_DIR` inside the volume. Fine here; **a blocker for an
  air-gapped company deployment**, which would have to pre-seed the cache or use the
  character splitter.
- **Reranker latency is unmeasured.** A CPU cross-encoder on GM's Xeon E5-2670, over
  `RAG_TOP_K=40` pairs, on every RAG turn. `RAG_RERANKING_BATCH_SIZE` (default 32) and
  `RAG_TOP_K` are the knobs.
- **Free-tier exhaustion is handled by the 429, not by a rate limit.** Mistral's free
  tier moves with global platform load, so no static `rpm`/`tpm` can track it. Fallback
  to paid Scaleway is driven by `retry_policy.RateLimitErrorRetries: 1`. Because
  `task-cheap` is a single-deployment group, `cooldown_time` does not apply
  (`cooldown_handlers.py:178`) — every call during exhaustion pays one retry before
  failing over. If that becomes noticeable, add a second deployment to the group to
  re-enable cooldown rather than inventing a limit.
