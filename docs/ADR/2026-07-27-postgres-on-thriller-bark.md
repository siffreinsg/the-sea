# The fleet's Postgres runs on Thriller Bark, against the placement rule

**2026-07-27 · Superseded by [one database per app](2026-07-28-one-database-per-app.md)**

The placement half stands: databases run on TB, with their consumers. Only the single
shared server is reversed.

Reverses the "no database" half of the LiteLLM plan, and the "Postgres belongs on GM"
assumption in the AI-platform roadmap.

LiteLLM was going to run config-file-only, with the database deferred to Phase 4 when
pgvector would force it. **LiteLLM's admin UI requires a database** — it is the virtual
key and spend store, and without one the UI has nothing to render. Wanting the UI is
wanting the database, so the deferral ended on day one rather than at Phase 4. Standing it
up now is also the cheaper order: pgvector was going to need a Postgres regardless, and
one server built once beats two built separately.

[Placement follows the benchmarks](2026-07-22-placement-follows-benchmarks.md) puts
databases on Going Merry — the disk-excellent box, where every other one already lives.
**This one goes on Thriller Bark anyway, because both of its consumers are there.**
LiteLLM is on TB and sits on the hot path of every request; Open-WebUI, which will hold
the pgvector store, is on TB too. On GM, every key lookup, every spend write, every
embedding write and every retrieval query would cross the mesh to reach a database whose
only users are on the other side of it. The disk advantage does not pay for that.

**Decision: one `pgvector/pgvector:0.8.5-pg17` on TB**, inside the LiteLLM stack, reached
by container name, no host port — the [bind rule](2026-07-19-services-bind-private-addresses.md)
is satisfied by absence. pgvector from the start so Phase 4 adds a schema, not a migration.

Consequences: TB's slow disk, accepted for small rows and short queries (reopens if
retrieval measurement says otherwise); backed up under the **critical** plan
(`runbooks/add-a-service.md` §3c, [secrets.md](../domains/secrets.md) for
`LITELLM_SALT_KEY`); Phase 5 cost-per-consumer dashboard unblocked; `STORE_MODEL_IN_DB`
stays off, consistent with [config as code](2026-07-26-open-webui-config-as-code.md).
