# Sidekick stack — the six containers the config review needs

**Status: steps 0, 1, 5 landed; step 2 dropped; 3 written but not deployed; 4, 6 open.**
Delete this file once the rest lands. Open items are tracked in [`../TODO.md`](../TODO.md).

Decisions and rationale are in
[`2026-07-26-ai-platform-config-review.md`](2026-07-26-ai-platform-config-review.md).
This file is the build order. `thriller-bark/open-webui/config.env` and
`thriller-bark/litellm/config.yaml` are already written and reference these services, so
**web search fails until they exist** — and Open-WebUI does not boot at all until step 5,
because its `VECTOR_DB=pgvector` landed ahead of its `DATABASE_URL`. Step 5 first, then the
rest in any order.

Mesh IPs: TB `100.64.0.2`, GM `100.64.0.1`. Follow
[`add-a-service`](../runbooks/add-a-service.md) for each ship dir.

## 0. Free-tier providers (no container)

`MISTRAL_API_KEY` is already in `thriller-bark/litellm/secrets.env`. That alone activates
the `task-cheap` group — **done**.

No `rpm`/`tpm` is set, deliberately: Mistral's free-tier limit moves with global platform
load rather than being a fixed quota, so any static cap is wrong in one direction or the
other. The 429 is the signal instead, handled by `retry_policy.RateLimitErrorRetries: 1`
plus the fallback to Scaleway.

Worth knowing: `task-cheap` is a **single-deployment group**, and
`cooldown_handlers.py:178` skips cooldown for those — so `allowed_fails` and
`cooldown_time` do not apply to it. Fallback on error is the entire mechanism. If free-tier
exhaustion ever becomes frequent enough that the per-call retry hurts, the fix is a second
deployment in the group (which re-enables cooldown), not a rate limit.

Verify after deploy: force a title generation and confirm the spend log shows
`mistral/mistral-small-latest` at zero cost, then confirm a fallback lands on
`scw-mistral-small-3.2-24b` when the free tier is unavailable.

Other free tiers worth adding the same way later, all natively supported by LiteLLM
v1.93.0 (`groq/`, `cerebras/`, `gemini/`, `openrouter/`): one credential, one
`model_name: task-cheap` deployment, and they load-balance within the group. **Every one of
them trains on what you send.** That is why only title/tag/query generation routes there,
and why main chat has no free-tier fallback.

## 1. Tika — TB

- Image `apache/tika:3.3.1.0-full` — **arm64 confirmed** via Docker Hub API; `-full` carries
  OCR and the wider parser set.
- Ship dir `thriller-bark/tika/`, on `the-sea-internal`, **no published port** — Open-WebUI
  reaches it as `http://tika:9998`. No Caddy block, no auth decision: it is not reachable
  off the network.
- Verify: `docker exec open-webui curl -fsS http://tika:9998/tika` returns the version
  banner, then upload a PDF and confirm text lands in `document_chunk`.

## 2. Reranker — dropped

Deployed, measured, removed. A CPU cross-encoder is far too slow on this hardware, so
retrieval is hybrid search alone and `RAG_TOP_K` is 8 rather than 40:
[why](../ADR/2026-07-28-no-reranking.md). Nothing left to build.

## 3. SearXNG — GM

Built. Every setting and why: `going-merry/searxng/secrets.settings.yml`, which is readable
in a diff apart from one password.

**Open-WebUI does not reach it on the mesh.** It is bridged, and the mesh guard DROPs
`172.16.0.0/12 → 100.64.0.0/10`, so the original `SEARXNG_QUERY_URL=http://100.64.0.1:8080`
could never have worked. It goes through a Caddy relay on `:8090`
([decision](../ADR/2026-07-29-caddy-relays-mesh-services-to-containers.md)). Step 4 inherits
this: Firecrawl gets `:8091`, not a public hostname.

Verify in order, on GM unless noted:

1. `docker exec searxng printenv SEARXNG_SECRET` — non-empty. Upstream's file sets the
   literal `ultrasecretkey` and the entrypoint's `sed` only fires when `settings.yml` is
   *absent*, so this env var is the only thing replacing it. Fails silently.
2. `curl 'http://100.64.0.1:8080/search?q=test&format=json' | jq '[.results[].engine]|unique'`
   — the only check that `search.formats` took, and it also shows which of the 7 engines
   actually answered.
3. Run step 2 a dozen times, *then* dump `/metrics` whole:
   `curl -s -w '\n%{http_code} %{content_type}\n' -u alloy:"$PW" http://100.64.0.1:8080/metrics`.
   Read four things off that one body, all of which the alert rules assume:
   - status. `200` = auth good, and an empty body then genuinely means no searches yet.
     `401` = the password in `alloy/secrets.env` and the one in `secrets.settings.yml`
     have diverged. `404` = `open_metrics` never took. The empty-is-normal trap below
     makes 401 easy to misread, so check the code, not the body.
   - **6** `searxng_engines_reliability` lines, not 7, until wikidata initialises. It 403s
     on the SPARQL call it makes at worker boot and a failed init is never retried, so it
     serves nothing and therefore reports nothing. `get_engines_stats` skips any engine
     with zero requests, so a freshly restarted instance exports nothing at all either.
     That is why the drift alert is guarded on request count rather than counting alone —
     and why it is currently paused.

   Names, labels and scale no longer need checking here: read off the pinned source
   (`searx/metrics/__init__.py` at `c01178d03`), the names carry `_total`, the only label
   is `engine_name`, reliability is `100 - sum(error percentages)` so 0-100, and
   `openmetrics()` builds its rows from `engine_stats['time']` — which means a zero-request
   engine is absent rather than 0, and the exporter's `or 0` coercion is unreachable.
4. `docker logs searxng | head -50` — check whether granian logs the query string. If it
   does, searches land in Loki from GM regardless of the relay's own log.
5. **On TB**, from inside the consumer:
   `docker exec open-webui curl -fsS -o /dev/null -w '%{http_code}\n' 'http://host.docker.internal:8090/healthz'`
   — this is the one that proves the relay works and the guard is not in the way.
6. Then a real web search in the chat UI.

## 4. Firecrawl — GM (3 containers)

- API + Redis + Playwright service. The Redis here is Firecrawl-internal and does not
  reopen the Redis question, which is out of scope for Open-WebUI.
- Ship dir `going-merry/firecrawl/`, API bound `100.64.0.1:3002`.
- **Reached through the Caddy relay on `:8091`**, already reserved, not a public hostname —
  same reasoning as step 3. `FIRECRAWL_API_BASE_URL` becomes
  `http://host.docker.internal:8091` in the same commit that adds the listener. Firecrawl
  does have an API key, so the public edge would also have been legitimate here; the relay
  is chosen so both services answer the question the same way.
- **Blocking check — Open-WebUI v0.10.2 speaks the v2 API** (`firecrawl.py:24-27`,
  `/v2/scrape`, `formats: ['markdown']`) and carries a v1/v2 response-shape shim
  (upstream issue #23966). If the self-hosted image only answers v1, web search breaks and
  the fallback is a plain Playwright container (`mcr.microsoft.com/playwright:v1.60.0-noble`
  running `playwright run-server`, version-pinned to the image's `playwright==1.60.0`) with
  `WEB_LOADER_ENGINE=playwright` and `PLAYWRIGHT_WS_URL`.

  ```
  curl -s http://100.64.0.1:3002/v2/scrape \
    -H 'Content-Type: application/json' \
    -d '{"url":"https://example.com","formats":["markdown"]}' | jq
  ```

- Self-hosted loses Fire-engine, so IP-block and bot-detection handling is absent. Expect
  some sites to fail; that is a known limit, not a misconfiguration.
- Second consumer to wire once it works: n8n. That reuse is the reason Firecrawl was chosen
  over a bare Playwright container.

## 5. Postgres cutover — TB

**No longer last, and no longer optional.** `VECTOR_DB=pgvector` is already in `config.env`
while `DATABASE_URL` was deferred to this step, so Open-WebUI raises at import
(`config.py:640`) and will not boot until this lands. Any restart since that config landed
would have hit it.

Open-WebUI now has [its own database](../ADR/2026-07-28-one-database-per-app.md) in its own
stack, so there is no role to create by hand — the `open-webui-db` container creates them
from `POSTGRES_USER`/`POSTGRES_DB` on first boot.

1. Backrest snapshot of `open-webui-data` first, so the discard is reversible for a while.
2. `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD` and `DATABASE_URL` are **already in
   `open-webui/secrets.env`** — done. `POSTGRES_USER` and `POSTGRES_DB` are both
   `openwebui` because the compose healthcheck hardcodes them; change one and
   `depends_on: service_healthy` never satisfies.

3. **Wipe and recreate the `open-webui-data` volume.** History is deliberately dropped —
   Open-WebUI does not migrate SQLite to Postgres, so pointing at an empty database is a
   fresh install either way and the old SQLite file would just sit there orphaned.
   Conversations survive as raw prompt/response in `LiteLLM_SpendLogs` for 180 days.
4. `ENABLE_OAUTH_SIGNUP=True`, redeploy, log in once through Authelia — the first user is
   promoted to admin (`utils/oauth.py:1923`) — then set it back to `False` and redeploy.
5. Confirm `PGVECTOR_INITIALIZE_MAX_VECTOR_LENGTH=3584` and `PGVECTOR_USE_HALFVEC=True` are
   live **before uploading a single document**. This boot is what creates the vector
   tables, so it is the moment the choice is committed. Wrong here means dropping the index
   and re-embedding the whole corpus at Scaleway's rate. A wrong length cannot boot
   silently — `config.py:647` raises — but a missing `halfvec` with a *lower* length would
   index happily and mismatch bge.
6. Verify the index type actually chosen:
   `\d+ document_chunk` in psql should show an **hnsw** index on a `halfvec` column.
7. Then upload one PDF and ask a question against it. That is the only check that Tika
   parses end to end and that hybrid search returns results with no reranker in the chain.
   If it comes back empty, `ENABLE_RAG_HYBRID_SEARCH=False`.

## 6. Virtual keys — per-key budgets

Not a config file: budgets live **on the keys**, set through LiteLLM's API or admin UI, so
nothing in `config.yaml` implements them. The `max_budget: 50` / `budget_duration: 30d` in
`litellm_settings` is only the global backstop.

Update the three existing keys — Open-WebUI €30, n8n €10, Karakeep €5, all `30d`:

```
curl -s -X POST http://127.0.0.1:4000/key/update \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H 'Content-Type: application/json' \
  -d '{"key":"sk-...","max_budget":30,"budget_duration":"30d"}'
```

The point of splitting them is isolation: a runaway n8n workflow must not consume the
budget the chat UI needs. Pair with an alert *before* a key hits its cap, or the first
symptom is a user seeing errors.

## Secrets to add (sops), in one place so none is missed

| Secret | File | Needed by |
|---|---|---|
| `MISTRAL_API_KEY` | `litellm/secrets.env` | step 0, the `task-cheap` free tier |
| `POSTGRES_USER` / `POSTGRES_DB` / `POSTGRES_PASSWORD` / `DATABASE_URL` | `open-webui/secrets.env` | step 5 — Open-WebUI is down until these land |
| `FIRECRAWL_API_KEY` | `open-webui/secrets.env` | step 4 — whatever the self-hosted instance is configured with |

`FIRECRAWL_API_KEY` is referenced by a comment in `config.env` and is easy to skip; it
fails at first use as an auth error rather than at boot.

## After it all lands

- Backrest: the critical plan already covers Postgres. Confirm the new `openwebui` database
  is inside it, and that the emptied `open-webui-data` volume is no longer carrying a dead
  SQLite file into every snapshot.
- Alloy: `otelcol.processor.filter "noise"` still has untuned Open-WebUI browser polling —
  read the routes off a real trace now that there is traffic worth tracing.
- Grafana: nothing new is required, but Tika's failure is currently invisible.
- Delete this file and the config-review plan once both are done.
