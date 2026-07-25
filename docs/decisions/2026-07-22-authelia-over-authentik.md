# Authelia, not Authentik

**2026-07-22 · Accepted · `e0ebb44`** — supersedes Authentik, which ran on GM pre-Komodo

Authentik stores its configuration in Postgres. That cannot be committed to git, so it
cannot survive "clone the repo, drop the age key, redeploy" — it would need its own
database restore, out of band, before anything could authenticate.

Authelia's entire configuration is YAML. It SOPS-encrypts into the repo like every other
secret, and it is one container instead of four.

**Consequence:** the identity provider is recoverable from the repo alone. Single user,
SQLite storage, sessions in memory (no redis). Authentik's legacy Postgres cluster on GM
is preserved but dead — see [the GM inventory](../legacy/going-merry-inventory.md).
