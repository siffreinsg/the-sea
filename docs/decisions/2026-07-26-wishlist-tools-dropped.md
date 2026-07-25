# Six wishlist tools dropped, one moved to Sunny

**2026-07-26 · Accepted**

The tool wishlist had accumulated candidates that were never re-examined after the things
around them changed. Reviewed in one pass; most of them stopped making sense.

**Dropped, superseded by something already running:**

- **Configarr** and **Huntarr** — Profilarr covers this. Two more arr-adjacent containers
  to maintain for overlapping function.
- **HedgeDoc** — never used, and collaborative notes are answered by the Obsidian vault +
  Syncthing setup.
- **Coolify** — it is a deploy platform, and [Komodo is already the deploy
  platform](2026-07-18-komodo-compose-not-kubernetes.md). Same class of overlap as
  nginx-proxy-manager against Caddy.

**Dropped, because the public instance is enough:**

- **IT-Tools** and **Stirling-PDF** — both are free and usable online, and neither holds
  state worth keeping local. Self-hosting them buys a container to patch and nothing else.
  Reconsider only if a genuinely private document has to go through one.

**Moved, not dropped:**

- **Maintainerr** runs on **The Thousand Sunny**, with the rest of the media stack, rather
  than as a Komodo stack on GM.

**Consequence:** `docs/domains/nodes.md` loses four names from the GM column and the
wishlist shrinks to Paperless-ngx, a habit tracker and a static site. Maintainerr on Sunny
makes the [deferred Sunny backup question](../future.md) concrete rather than theoretical
— there is now app state there that only Sunny holds, and Sunny is
[off the mesh](2026-07-25-sunny-stays-off-the-mesh.md) with no root and no Docker.
