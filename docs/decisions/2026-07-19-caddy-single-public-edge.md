# One public edge: Caddy on Thriller Bark

**2026-07-19 · Accepted · `627778a`**

Exactly one machine faces the internet, and exactly one process terminates TLS on it.
Everything else binds a private address and is reached through the mesh.

Caddy holds a wildcard certificate for `*.siffreinsigy.me` via Let's Encrypt DNS-01
against the Cloudflare API. Cloudflare is DNS-only (grey cloud) — no proxying, no WAF,
no third party terminating TLS.

**Consequence:** TB is a single point of failure for all ingress, accepted. The wildcard
means no per-service DNS record, which brings its own trap ([networking](../domains/networking.md):
a name with any existing record stops being covered). Sunny's apps stay outside this
edge entirely, on Ultra.cc's own nginx.
