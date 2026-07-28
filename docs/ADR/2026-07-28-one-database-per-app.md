# One database per app, inside the app's stack

**2026-07-28 · Accepted**

Supersedes the sharing half of
[Postgres on Thriller Bark](2026-07-27-postgres-on-thriller-bark.md); its placement half
still holds, databases stay on TB with their consumers.

One shared Postgres was chosen because building one server beats building two. Two days of
it produced a shared service living inside another service's stack, a `depends_on` that
cannot cross stacks, LiteLLM redeploys that would take Open-WebUI's vector store down, and
one Postgres version pinning two apps' upgrade schedules together. Dawarich and
your_spotify already ship their own databases, so per-app was the fleet's real pattern and
the shared one was the exception.

An app's database is a private dependency: same stack, no `the-sea-internal`, no host port,
reached by service name on the stack's own network.

Consequences:

- Two Postgres on TB, ~200 MB idle against 24 GB. Not the constraint.
- Two `pg_dump` targets rather than one. `backups/run.sh` currently has neither.
- LiteLLM's database keeps the pgvector image and the `litellm_` volume prefix. Historical,
  and not worth a dump to rename.
- Databases are named `<app>-db`, never `postgres`, so no two stacks publish the same short
  name. Renaming LiteLLM's means its `DATABASE_URL` host changes with it.
