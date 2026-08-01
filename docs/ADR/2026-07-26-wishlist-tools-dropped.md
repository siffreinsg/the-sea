# Six wishlist tools dropped, one moved to Sunny

**2026-07-26 · Accepted**

The tool wishlist had accumulated candidates that were never re-examined after the things
around them changed. Reviewed in one pass; most of them stopped making sense.

**Dropped, superseded by something already running:** Configarr and Huntarr (Profilarr
covers this), HedgeDoc (Obsidian vault + Syncthing already answers collaborative notes),
Coolify (overlaps [Komodo](2026-07-18-komodo-compose-not-kubernetes.md), same class as
nginx-proxy-manager against Caddy).

**Dropped, public instance is enough:** IT-Tools, Stirling-PDF — both free online, neither
holds state worth keeping local. Reconsider only if a genuinely private document needs one.

**Moved, not dropped:** Maintainerr runs on **The Thousand Sunny** with the rest of the
media stack, rather than as a Komodo stack on GM.

**Consequence:** `docs/domains/nodes.md` loses four names from the GM column and the
wishlist shrinks to Paperless-ngx, a habit tracker and a static site. Maintainerr on Sunny
makes the [deferred Sunny backup question](../FUTURE.md) concrete rather than theoretical
— there is now app state there that only Sunny holds, and Sunny is
[off the mesh](2026-07-25-sunny-stays-off-the-mesh.md) with no root and no Docker.
