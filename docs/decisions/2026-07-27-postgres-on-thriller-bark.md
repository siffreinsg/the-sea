# The fleet's Postgres runs on Thriller Bark, against the placement rule

**2026-07-27 · Accepted**

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

**Decision: one `pgvector/pgvector:0.8.5-pg17` on TB**, inside the LiteLLM stack, on
`the-sea-internal`, with no host port at all — every consumer reaches it by container
name, so there is nothing to bind and the
[bind rule](2026-07-19-services-bind-private-addresses.md) is satisfied by absence. The
pgvector image is used from the start so Phase 4 adds a schema rather than a migration.

Consequences:

- It is on TB's slow disk. Accepted: the workload is small rows and short queries, not the
  throughput case the placement rule was written for. If retrieval turns out to be the
  thing limiting RAG, that measurement reopens this.
- Stateful and holding secrets material (virtual keys, spend logs) → `backup.sh` and the
  **critical** plan, per `runbooks/add-a-service.md` §3c.
- `LITELLM_SALT_KEY` must be set from the first boot and never rotated: it encrypts the
  credentials stored in the database, and a restore under a different salt leaves every
  stored key undecryptable. Same failure class as `WEBUI_SECRET_KEY`.
- The Phase 5 cost-per-consumer dashboard is no longer blocked.
- `STORE_MODEL_IN_DB` stays off. The model list remains in committed YAML, consistent with
  [config as code](2026-07-26-open-webui-config-as-code.md); the UI's model pages are
  read-only as a result.
