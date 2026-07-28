# Sidekick stack — the six containers the config review needs

**Status: steps 0-2 landed (Mistral key, Tika, Infinity); 3-6 open.** Delete this file once
the rest lands. Open items are tracked in [`../TODO.md`](../TODO.md).

Decisions and rationale are in
[`2026-07-26-ai-platform-config-review.md`](2026-07-26-ai-platform-config-review.md).
This file is the build order. `thriller-bark/open-webui/config.env` and
`thriller-bark/litellm/config.yaml` are already written and reference these services, so
**Open-WebUI will boot but RAG and web search will fail until they exist**. Build in this
order; nothing here depends on a later step.

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

## 2. Infinity reranker — GM

- Serves `BAAI/bge-reranker-v2-m3` — a real cross-encoder, unlike Scaleway's `/v1/rerank`.
- Ship dir `going-merry/infinity/`, bound to `100.64.0.1:7997` so TB's LiteLLM can reach it
  over the mesh. No public route.
- x86 only in practice, which is why it is on GM rather than TB.
- **Verify before trusting the LiteLLM entry** — this is the exact failure the last session
  recorded (config written from a type file, not live output):

  ```
  # against Infinity directly
  curl -s http://100.64.0.1:7997/v1/rerank \
    -H 'Content-Type: application/json' \
    -d '{"model":"BAAI/bge-reranker-v2-m3","query":"capital of France",
         "documents":["Paris is the capital.","Bananas are yellow."]}' | jq

  # then through LiteLLM, which must return the same ordering
  curl -s http://127.0.0.1:4000/v1/rerank \
    -H "Authorization: Bearer $VIRTUAL_KEY" -H 'Content-Type: application/json' \
    -d '{"model":"bge-reranker-v2-m3","query":"capital of France",
         "documents":["Paris is the capital.","Bananas are yellow."]}' | jq
  ```

- Then measure latency at `RAG_TOP_K=40`. GM's Xeon E5-2670 is weak per core and this is a
  CPU cross-encoder over 40 pairs of ~800-token chunks on **every** RAG turn. If it hurts,
  turn `RAG_RERANKING_BATCH_SIZE` (default 32) or drop `RAG_TOP_K` — both are cheap to
  change, unlike the vector dimension.

## 3. SearXNG — GM

- Ship dir `going-merry/searxng/`, bound `100.64.0.1:8080`.
- **`json` must be in `settings.yml` under `search.formats`** — it is not there by default,
  and without it Open-WebUI receives HTML and web search fails in a way that looks like a
  parsing bug.
- Set a `server.secret_key`, and expect to revisit when upstream engines rate-limit GM's IP.
- Verify: `curl 'http://100.64.0.1:8080/search?q=test&format=json' | jq '.results|length'`.

## 4. Firecrawl — GM (3 containers)

- API + Redis + Playwright service. The Redis here is Firecrawl-internal and does not
  reopen the Redis question, which is out of scope for Open-WebUI.
- Ship dir `going-merry/firecrawl/`, API bound `100.64.0.1:3002`.
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

Do this **last**: it is the only destructive step.

1. Backrest snapshot of `open-webui-data` first, so the discard is reversible for a while.
2. Create role and database (`openwebui`), and confirm `CREATE EXTENSION vector` works —
   the image is already `pgvector/pgvector:0.8.5-pg17`.
3. `DATABASE_URL` into `open-webui/secrets.env` via sops.
4. **Wipe and recreate the `open-webui-data` volume.** History is deliberately dropped;
   conversations survive as raw prompt/response in `LiteLLM_SpendLogs` for 180 days.
5. `ENABLE_OAUTH_SIGNUP=True`, redeploy, log in once through Authelia — the first user is
   promoted to admin (`utils/oauth.py:1923`) — then set it back to `False` and redeploy.
6. Confirm `PGVECTOR_INITIALIZE_MAX_VECTOR_LENGTH=3584` and `PGVECTOR_USE_HALFVEC=True` are
   live **before uploading a single document**. Wrong here means dropping the index and
   re-embedding the whole corpus at Scaleway's rate. A wrong length cannot boot silently —
   `config.py:647` raises — but a missing `halfvec` with a *lower* length would index
   happily and mismatch bge.
7. Verify the index type actually chosen:
   `\d+ document_chunk` in psql should show an **hnsw** index on a `halfvec` column.

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
| `DATABASE_URL` | `open-webui/secrets.env` | step 5, Postgres cutover |
| `RAG_EXTERNAL_RERANKER_API_KEY` | `open-webui/secrets.env` | step 2 — the same LiteLLM virtual key as `OPENAI_API_KEY` |
| `FIRECRAWL_API_KEY` | `open-webui/secrets.env` | step 4 — whatever the self-hosted instance is configured with |

The last two are referenced by comments in `config.env` and are easy to skip; both fail at
first use as an auth error rather than at boot.

## After it all lands

- Backrest: the critical plan already covers Postgres. Confirm the new `openwebui` database
  is inside it, and that the emptied `open-webui-data` volume is no longer carrying a dead
  SQLite file into every snapshot.
- Alloy: `otelcol.processor.filter "noise"` still has untuned Open-WebUI browser polling —
  read the routes off a real trace now that there is traffic worth tracing.
- Grafana: nothing new is required, but the reranker and Tika are two more things whose
  failure is currently invisible.
- Delete this file and the config-review plan once both are done.
