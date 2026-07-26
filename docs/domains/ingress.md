# Ingress and authentication

Caddy on TB is the only process terminating public TLS
([why](../decisions/2026-07-19-caddy-single-public-edge.md)). Config is a static
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
- **The admin API on `127.0.0.1:2019` is unauthenticated read/write config** for any local
  user. `admin off` is not available because Alloy scrapes it; closing it needs a
  dedicated loopback metrics site first. Tracked in [future](../future.md).

## Auth outcomes

Every service lands in one of three outcomes, picked by capability
([the rule](../decisions/2026-07-23-three-auth-outcomes.md)). Authelia's
`default_policy` is `two_factor` with **no** per-host rules, so there is no host with a
weaker policy and none without one.

| Outcome | Services | Notes |
|---|---|---|
| **a — Authelia OIDC client** | dawarich, profilarr, cleanuparr, open-webui | Native login button, real identity. Caddy is a plain `reverse_proxy` |
| **b — Caddy `forward_auth`** | your_spotify, litellm | `your_spotify` bypasses `/api/*` at the edge; `litellm` gates the whole host |
| **c — own login, judged sufficient** | komodo, grafana, backrest ×2, actualbudget, n8n | Recorded per app below, never left implicit |
| **none, by design** | `up` (static string), headscale (control server, must be publicly reachable; its API returns 401) | |

Outcome (c), with the reason each time:

- **Actual Budget** — password-only. Actual enforces one active auth method server-side,
  so OIDC and password cannot coexist; OIDC was tried and reverted.
- **n8n** — own login plus enrolled 2FA. Double-login friction was not judged worth it, and
  it now carries no edge bypass at all.
- **Komodo, Grafana, Backrest** — own auth, all three confirmed to reject unauthenticated
  API calls.

Two notes on the newest entries:

- **Open-WebUI is the fleet's first *same-node* OIDC client** — a container on TB dialling
  TB's own public `auth.` name, which hairpins past the `INPUT` default REJECT. The other
  three clients are on GM, so this path has no precedent here. If discovery fails, the fix
  is **not** an internal `http://authelia:9091`: Authelia advertises the public URL as its
  issuer, so issuer validation breaks. Put Authelia on `the-sea-internal` instead and
  resolve the public name internally.
- **LiteLLM's `ai.` host is the admin UI only, and `forward_auth` covers all of it.** No
  path split: the UI is a shell that XHRs to root-level endpoints (`/model/info`,
  `/key/list`, `/spend/logs`), so gating `/ui*` alone serves a page that loads and shows
  nothing. `/v1/*` is deliberately unrouted — every consumer reaches the gateway privately,
  on `the-sea-internal` by container name or the `100.64.0.2` mesh bind. **Publishing the
  API would put the fleet's only provider key behind a single bearer token on the public
  internet; that needs its own decision, not a Caddyfile edit.** Accepted friction: two
  logins to reach the UI, Authelia then LiteLLM's own `UI_USERNAME`/`UI_PASSWORD`.

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
