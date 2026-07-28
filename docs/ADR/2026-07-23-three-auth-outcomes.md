# Every service lands in one of three auth outcomes

**2026-07-23 · Accepted · `be0eea0`**

A single Authelia cookie on `*.siffreinsigy.me` gives SSO across the estate, with
`default_policy: two_factor` and no per-host weakening rules. But not every app can use
it the same way, and forcing one mechanism everywhere produces either double-login
friction or a bypass someone will get wrong.

Pick by capability, in this order:

1. **App supports OIDC** → make it an Authelia client. Native login button, real
   identity, no double gate. Caddy stays a plain `reverse_proxy`.
2. **No OIDC** → Caddy `forward_auth` to Authelia.
3. **Own login with 2FA judged sufficient** → neither. Record the decision explicitly.

**Consequence:** outcome (3) is a judgement call that must be written down per app, not
left implicit — the current assignments are in [ingress](../domains/ingress.md). Outcome
(2) needs care with path bypasses: Caddy's `handle` mutual exclusion only applies between
siblings, which is what broke n8n's webhook bypass once.
