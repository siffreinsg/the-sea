# Habit tracker: Beaverhabits, not Habitica

**2026-07-25 · Reopened 2026-07-26** — Beaverhabits is no longer the answer and nothing
replaces it yet. Not superseded, because there is no replacement decision to point at; the
comparison below stands and is worth reading before picking again. Deploy nothing until a
new record exists.

The wishlist item was left as "research pending". Researched: **Beaverhabits**.

Habitica is a game that contains a habit tracker. It's the more alive project by a wide
margin (14k stars, pushed 2026-07-25, `v5.48.7`) and that's exactly the problem — it
brings **MongoDB**, a separately-built web client, and an RPG layer nobody asked for.
That's a database in the backup plan, a dump script, a restore path, and a monthly
upgrade, to record whether I flossed.

Beaverhabits (1.8k stars, pushed 2026-07-19, `v0.9.1`) is a single container that
stores either a JSON file per user or one SQLite file (`HABITS_STORAGE=USER_DISK` or
`DATABASE`). Cold state, no dump needed, `:ro` into Backrest's bulk plan like the rest.

**Consequence:** no OIDC — own login, lands as auth outcome **b or c**, not **a**, decide
when deployed ([three-outcomes rule](2026-07-23-three-auth-outcomes.md)). Second: no
released image tag to pin (Docker Hub only ships `nightly`/`sha-*`, semver tags stuck at
2024's `v0.1.5` while GitHub releases reached `v0.9.1`) — [pin-every-image](../../AGENTS.md)
satisfied with an image digest instead, upgrades manual, accepted for the small container.

If gamification is what actually makes the habit stick, this is cheap to reverse — the
data is a JSON file.
