# Ingress and authentication

Caddy on TB is the only process terminating public TLS
([why](../ADR/2026-07-19-caddy-single-public-edge.md)). Config is a static
`Caddyfile` in the repo; wildcard certificate via Let's Encrypt DNS-01 against the
Cloudflare API.

## Caddyfile rules

- **`handle` mutual exclusion only applies between siblings.** A `handle` containing a
  nested `handle` *plus* trailing loose directives does not short-circuit — wrap every
  branch in its own `handle {}`. This is what broke n8n's webhook bypass.
- The terminal `handle { abort }` catches unmatched hosts. Verified: an unknown subdomain
  completes the TLS handshake against the wildcard and then gets an empty reply.
- **After a Caddyfile change it is `up -d --force-recreate`, never `caddy reload`** — the
  file is bind-mounted and inode-pinned, see [deploy](deploy.md).
- The site block sets HSTS (`max-age=31536000; includeSubDomains`). No `preload` until
  `includeSubDomains` is verified safe for every name under the apex — preload is
  effectively irreversible.
- Access logging is on (`log { output stdout / format json }`). Alloy ships it to Loki as
  `container="caddy"`, 30-day retention. It is the only record that a public request
  happened.
- **The admin API is off.** Metrics are served from a dedicated loopback site,
  `http://127.0.0.1:2020/metrics`, which Alloy scrapes instead of `:2019`.

## Auth outcomes

Every service lands in one of three outcomes, picked by capability
([the rule](../ADR/2026-07-23-three-auth-outcomes.md)). Authelia's
`default_policy` is `two_factor` with **no** per-host rules, so there is no host with a
weaker policy and none without one.

| Outcome | Services | Notes |
|---|---|---|
| **a — Authelia OIDC client** | dawarich, profilarr, cleanuparr, open-webui, litellm | Native login button, real identity. Caddy is a plain `reverse_proxy` |
| **b — Caddy `forward_auth`** | your_spotify | `/api/*` bypassed at the edge; the app enforces its own session |
| **c — own login, judged sufficient** | komodo, grafana, backrest ×2, actualbudget, n8n | Recorded per app below, never left implicit |
| **none, by design** | `up` (static string), headscale (control server, must be publicly reachable; its API returns 401) | |

Outcome (c), with the reason each time:

- **Actual Budget** — password-only. Actual enforces one active auth method server-side, so
  OIDC and password cannot coexist.
- **n8n** — own login plus enrolled 2FA, and no edge bypass at all. Not worth a second login.
- **Komodo, Grafana, Backrest** — own auth, all three confirmed to reject unauthenticated
  API calls.

Two notes on the newest entries:

- **Same-node OIDC works — verified 2026-07-27.** Open-WebUI and LiteLLM are the fleet's
  first, containers on TB dialling TB's own public `auth.` name and hairpinning past the
  `INPUT` default REJECT. It needed no workaround. Kept for the day one breaks: the fix
  is **not** an internal `http://authelia:9091`, because Authelia advertises the public URL
  as its issuer and issuer validation would break. Resolve the public name internally
  instead (Authelia is already on `edge`, same network as every service Caddy proxies to
  — except n8n, deliberately isolated on its own network; see `docs/REFERENCE.md`).
- **LiteLLM is an OIDC client, not `forward_auth`.** Its admin UI has a mandatory login
  that cannot be disabled, so `forward_auth` would mean two logins every time.
  SSO is free below five users at v1.93.0 (`ui_sso.py:858`) — no
  `LITELLM_LICENSE` needed — which makes Authelia the single door instead of an extra one.
  `UI_USERNAME`/`UI_PASSWORD` stay as break-glass: `POST /login`
  (`proxy_server.py:13232`) is a plain form handler with no SSO gate, so it keeps working
  even when the UI redirects to Authelia. Unlike Open-WebUI, this app is not SSO-only.
  **What that trades away, stated plainly:** LiteLLM's API surface is now publicly
  reachable, protected by its own bearer keys rather than by the edge. Same posture as
  Komodo and Grafana. **No path allowlist on `/v1/*`** — the UI calls root-level endpoints,
  so the list would be long and would break on upgrade.
  The mitigations that must stay true: the master key is a long random, never shared with
  a consumer, and every consumer holds a virtual key instead. Same-node callers use
  `ai-backends` (`http://litellm:4000`) and do not depend on the public name;
  **cross-node callers do**, there is no mesh bind
  ([why](../ADR/2026-07-27-cross-node-calls-use-the-public-edge.md)).
  Its client is `require_pkce: false` — fastapi-sso's generic provider sends a verifier but
  the flow isn't worth betting a login on — and `client_secret_basic`, which is what
  fastapi-sso uses. **SSO logins land as a second, non-admin user** — the UI_USERNAME
  account's `user_id` is the username, an SSO login's is the email, so they never match.
  `PROXY_ADMIN_ID` set to that email promotes the SSO user to `proxy_admin` on every login
  and writes it back to the DB (`ui_sso.py:1723`), which is idempotent and survives a
  restore. Promoting by hand in the UI would not.
  **`default_user_id` beside your account is not a stray user — leave it.** It is a
  hardcoded constant (`constants.py:1406`, `LITELLM_PROXY_ADMIN_NAME`) that LiteLLM uses
  as the proxy-level budget row, the global-spend cache key and the actor on config audit
  logs. It is bookkeeping, not an identity, and there is nothing to merge it with;
  deleting it or resetting the database to "clean it up" would break the global spend row
  and the audit trail for no gain.

**Pick `token_endpoint_auth_method` from the app's HTTP client, not from taste.** It is
not negotiated — a mismatch fails the token exchange with `invalid_client`, which reads
like a wrong secret. Open-WebUI uses authlib, which sends `client_secret_basic` and offers
no env to change it; LiteLLM's fastapi-sso does the same. `profilarr` and `cleanuparr` are
`client_secret_post` and work — don't "unify" them.

All OIDC clients are confidential (`public: false`), carry
`authorization_policy: two_factor`, and have exact redirect URIs — none wildcarded.
`open-webui` sets `require_pkce: true` (`OAUTH_CODE_CHALLENGE_METHOD=S256`, the only value
v0.10.2 accepts). `profilarr` is the one client with `require_pkce: false`, deliberate and acceptable on a
confidential client using `client_secret_post`.

## Gotchas

- **Don't write app config from memory. Pin the version, read that version's docs.**
  Authelia's schema moved hard at 4.38 — session became a `cookies:` array, JWT secrets
  moved under `identity_validation`, the forward-auth path changed.
- **Set an OIDC app's redirect URI explicitly.** Don't trust its auto-derivation from a
  hostname env var; that bit Dawarich.
- **A Rails app told its protocol is `https`** will `force_ssl`-redirect anything without
  `X-Forwarded-Proto: https` — including its own container-internal healthcheck on
  loopback, which can never be HTTPS since TLS terminates at Caddy. The symptom looks like
  a raw TLS error, not a 301, and it blocks `depends_on: service_healthy`. Send the header
  from the healthcheck too. Hit this on Dawarich.
