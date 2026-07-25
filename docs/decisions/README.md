# Decision record

Why things are the way they are. One file per decision, so a decision is findable by
filename and a reversal is visible rather than silently overwritten.

Rules: never delete an entry, mark it `Superseded by <link>` — knowing why something was
reversed is worth more than the original. Keep entries short; if one needs sixty lines,
the content belongs in a [domain doc](../domains/) and the decision is a paragraph.
New decision = new dated file + one row here.

| Date | Decision | Status |
|---|---|---|
| 2026-07-26 | [Six wishlist tools dropped, one moved to Sunny](2026-07-26-wishlist-tools-dropped.md) | Accepted |
| 2026-07-26 | [Syncthing gets a public port, the one exception to the bind rule](2026-07-26-syncthing-public-port.md) | Accepted |
| 2026-07-25 | [Habit tracker: Beaverhabits, not Habitica](2026-07-25-beaverhabits-not-habitica.md) | **Reopened** 2026-07-26 |
| 2026-07-25 | [Operating rules are versioned; HANDOFF stays local](2026-07-25-operating-rules-versioned.md) | Accepted |
| 2026-07-25 | [The container/tailnet block lives in raw/PREROUTING](2026-07-25-mesh-guard-in-raw-prerouting.md) | Accepted |
| 2026-07-25 | [The komodo stack is not managed by Komodo](2026-07-25-komodo-stack-hand-managed.md) | Accepted |
| 2026-07-25 | [Alerts go to Telegram, through Den Den Mushi](2026-07-25-telegram-not-ntfy.md) | Accepted |
| 2026-07-25 | [Backrest config and Komodo alerters stay UI-managed](2026-07-25-backrest-and-alerters-stay-ui-managed.md) | Accepted |
| 2026-07-25 | [The Thousand Sunny stays off the mesh](2026-07-25-sunny-stays-off-the-mesh.md) | Accepted |
| 2026-07-23 | [The observability stack runs on Going Merry](2026-07-23-observability-on-going-merry.md) | Accepted |
| 2026-07-23 | [Every service lands in one of three auth outcomes](2026-07-23-three-auth-outcomes.md) | Accepted |
| 2026-07-23 | [Code-Server is dropped, not deferred](2026-07-23-code-server-dropped.md) | Accepted |
| 2026-07-22 | [Placement follows the benchmarks, not the labels](2026-07-22-placement-follows-benchmarks.md) | Accepted |
| 2026-07-22 | [Authelia, not Authentik](2026-07-22-authelia-over-authentik.md) | Accepted |
| 2026-07-21 | [DR identifiers use full node names](2026-07-21-full-node-names-for-dr-identifiers.md) | Accepted |
| 2026-07-21 | [Database dumps run from a host systemd timer](2026-07-21-dumps-via-host-systemd-timer.md) | Accepted |
| 2026-07-21 | [Backups: Backrest → restic → Proton Drive + Mega](2026-07-21-backrest-restic-proton-mega.md) | Accepted |
| 2026-07-19 | [Services bind a private address, never 0.0.0.0](2026-07-19-services-bind-private-addresses.md) | Accepted |
| 2026-07-19 | [One public edge: Caddy on Thriller Bark](2026-07-19-caddy-single-public-edge.md) | Accepted |
| 2026-07-18 | [Secrets live in git, encrypted with SOPS + age](2026-07-18-sops-age-secrets-in-git.md) | Accepted |
| 2026-07-18 | [Headscale for the mesh](2026-07-18-headscale-mesh.md) | Accepted |
| 2026-07-18 | [Komodo + Compose, not Kubernetes](2026-07-18-komodo-compose-not-kubernetes.md) | Accepted |

Reversed along the way, recorded inside the entry that replaced them: WireGuard
hub-and-spoke → Headscale, Authentik → Authelia, Actual Budget OIDC → password-only,
n8n `forward_auth` → own login, `login.` → `auth.` subdomain.
