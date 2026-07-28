# AI platform config review — Open-WebUI + LiteLLM

**Status: decisions agreed, not yet implemented.** Delete this file once landed.

Reviewed against **Open-WebUI v0.10.2** (git tag, source) and **LiteLLM v1.93.0**, not the
docs pages — the Open-WebUI docs page targets v0.10.0 and has wrong defaults. All 784 vars
on `docs/reference/env-configuration.mdx` were enumerated and bucketed; the LiteLLM side
was enumerated from `ConfigGeneralSettings` (58 keys), `Router.__init__`, and the 259 env
vars read across `litellm/proxy/`.

## Purpose

This deployment is a **lab for a company build**. Choices are made for what would be right
at company scale, not for what is cheapest here. Hard rule: **no external paid services**
beyond Scaleway.

## Findings that drove the decisions

- `VECTOR_DB` defaults to **`chroma`** (`config.py:493`) and `PGVECTOR_DB_URL` inherits
  `DATABASE_URL` (`config.py:638`) — so "Postgres is the pgvector store" was aspirational.
- `PGVECTOR_INITIALIZE_MAX_VECTOR_LENGTH > 2000` **raises `ValueError`** without
  `PGVECTOR_USE_HALFVEC` (`config.py:647`). halfvec also selects an **hnsw** index rather
  than ivfflat (`pgvector.py:187`).
- **`-slim` installs the full `requirements.txt`.** `USE_SLIM=true` only skips downloading
  model *weights* (`Dockerfile:156`, workflow `docker.yaml:54`). `requirements-min.txt` is
  referenced by no image. The current `config.env` comment claiming otherwise is wrong.
  Consequence: `tiktoken` and nltk `punkt_tab` fetch at **runtime** on first use.
- `ENABLE_CODE_EXECUTION` and `ENABLE_CODE_INTERPRETER` both default **`True`**
  (`config.py:399,414`) — currently live and unintended.
- `DATABASE_POOL_SIZE` unset selects **`NullPool`** (`db.py:278`): a new Postgres
  connection per request.
- `RAG_FILE_MAX_SIZE` / `_MAX_COUNT` default to `None` (unlimited) and
  `RAG_ALLOWED_FILE_EXTENSIONS` to `[]` (everything).
- Scaleway's `/v1/rerank` serves `qwen3-embedding-8b`; their own docs state it is
  equivalent to cosine similarity on normalised vectors — i.e. what Open-WebUI already
  does with no reranker. Not a cross-encoder.
- LiteLLM `ui_access_mode` defaults **`"all"`**, not admin-only, on a UI published at
  `ai.siffreinsigy.me`.
- Total LiteLLM spend to date: **€0.000056**. Budgets below are guardrails, not forecasts.

## Storage

| Setting | Value | Note |
|---|---|---|
| App DB + vector store | Postgres on TB, one instance, no published port | GM's 40x IOPS is irrelevant for a corpus that fits page cache; splitting needs a mesh-published DB holding chunk text on a provider-controlled kernel |
| Migration | **fresh start, history dropped** | conversations survive as raw prompt/response in `LiteLLM_SpendLogs` |
| `open-webui-data` volume | wiped on cutover, restic snapshot first | orphaned `webui.db`, chroma store, `uploads/` |
| `VECTOR_DB` | `pgvector` | |
| `PGVECTOR_INITIALIZE_MAX_VECTOR_LENGTH` | `3584` | **before the first document is indexed** |
| `PGVECTOR_USE_HALFVEC` | `true` | required at 3584; gives hnsw |
| `PGVECTOR_PGCRYPTO` | off | not explored, deliberately |
| `DATABASE_POOL_SIZE` / `_MAX_OVERFLOW` | `10` / `5` | |

## RAG pipeline

Tika (TB) → token chunking → bge @ 3584 → hybrid search, top-k 40 → Infinity
cross-encoder (GM) → 8 chunks into the prompt.

| Setting | Value | Note |
|---|---|---|
| `CONTENT_EXTRACTION_ENGINE` | `tika` + `TIKA_SERVER_URL` | `apache/tika:3.3.1.0-full`, **arm64 confirmed** |
| `RAG_TEXT_SPLITTER` | `token` | unit changes meaning vs the character splitter |
| `CHUNK_SIZE` / `CHUNK_OVERLAP` | `800` / `100` | well under bge's 8k |
| `ENABLE_MARKDOWN_HEADER_TEXT_SPLITTER` | `true` | pre-pass, markdown corpora only |
| `RAG_EMBEDDING_*` | unchanged — LiteLLM + `scw-bge-multilingual-gemma2` | |
| `ENABLE_RAG_HYBRID_SEARCH` | `true` | pgvector has native `hybrid_search` |
| `RAG_TOP_K` | `8` | no reranker to narrow a wider pool |
| `RAG_RELEVANCE_THRESHOLD` / `RAG_HYBRID_BM25_WEIGHT` | `0.0` / `0.5` | defaults kept; scores aren't comparable across models |
| `RAG_RERANKING_ENGINE` | unset | [measured too slow](../ADR/2026-07-28-no-reranking.md) |
| `RAG_FILE_MAX_SIZE` / `_MAX_COUNT` | `25` MB / `10` | |
| `RAG_ALLOWED_FILE_EXTENSIONS` | explicit allow-list | also shrinks Tika's parser attack surface |
| unscoped collections, bypass-retrieval, full-context, local web fetch | defaults kept (all `False`) | already safe |

## Web search

| Setting | Value | Note |
|---|---|---|
| `ENABLE_WEB_SEARCH` | `true` | |
| `WEB_SEARCH_ENGINE` | `searxng`, self-hosted **on GM** | keeps scraping reputation off TB's public-edge IP |
| `WEB_LOADER_ENGINE` | `firecrawl`, self-hosted **on GM** | fleet content-acquisition tier, reusable by n8n; is Playwright underneath |
| `WEB_SEARCH_RESULT_COUNT` | `5` | embedding + retrieval kept, no bypass |
| `YOUTUBE_LOADER_LANGUAGE` | `fr,en` | defaults `en` |

## Feature surface

| Setting | Value |
|---|---|
| `ENABLE_CODE_EXECUTION` / `_INTERPRETER` | **`False`** — deferred to the Open Terminal / ContainerSSH decision |
| TTS / voice mode | off, dead by constraint — Scaleway has no `/v1/audio/speech` |
| Image generation | off (already the default) |
| `ENABLE_MEMORIES` / `ENABLE_NOTES` / `ENABLE_MESSAGE_RATING` | left on; rating kept as model-quality signal |
| `AUDIT_LOG_LEVEL` | stays `NONE`; **remove `ENABLE_AUDIT_STDOUT`** rather than imply a feature that does nothing |
| `ENABLE_AUDIT_LOGS_FILE` | keep `False` (defaults `True`) |
| `JWT_EXPIRES_IN` | `24h` (default `4w`, no revocation list) |
| `ENABLE_ADMIN_CHAT_ACCESS` / `ENABLE_ADMIN_EXPORT` | **left `True`** — sole admin and user, and needed when test/external accounts are added. Already off on the company infrastructure. |

Out of scope by decision: Redis/websockets, LDAP, SCIM, OAuth group/role claims — infra
layer, not feature exploration.

## LiteLLM

| Key | Value | Note |
|---|---|---|
| `router_settings` | `request_timeout`, `num_retries`, `allowed_fails`, `cooldown_time` | bound failures |
| fallbacks | **only `task-cheap` → `scw-mistral-small-3.2-24b`** | refines the earlier "no fallbacks" call rather than reversing it: user-facing chat still fails honestly, but a *free-tier quota* fallback is not a quality judgement |
| free tier | Mistral La Plateforme as the `task-cheap` primary | mechanical calls only — title/tag/query generation. **Free tiers train on what you send.** Title generation still sees the user's first message, so this is a bounded trade, not zero exposure |
| budgets | global €50/30d; per-key OWUI €30, n8n €10, Karakeep €5 | isolation matters more than the totals |
| cache | `type: local`, **embeddings only** | per-replica; stops helping when scaled out |
| `cancel_on_disconnect` | `true` | "stop" currently still pays for the full generation |
| `max_request_size_mb` / `max_response_size_mb` | `20` / `20` | |
| `global_max_parallel_requests` | capped, headroom for parallel embedding batches | |
| `background_health_checks` + `health_check_interval` | on | |
| `alerting` / `alert_to_webhook_url` | **off** | one alerting path: Grafana + Den Den Mushi |
| `ui_access_mode` | `admin_only` | **defaults `"all"`** on a publicly-resolvable UI |
| `allowed_routes` / `enable_public_model_hub` | left open | every consumer is ours; narrowing breaks new ones with confusing 404s |
| `json_logs` | `true` | Loki can query by field instead of grepping |
| `database_connection_pool_limit` | set | its own Postgres now, not shared |
| `turn_off_message_logging` | stays `False` | the conversation archive depends on it |
| `redact_user_api_key_info` | stays `False` | per-key attribution is the point of virtual keys |

## New containers (5)

| Service | Node | Why there |
|---|---|---|
| Tika | TB | arm64 confirmed; co-located with the uploader |
| SearXNG | GM | scraping reputation off TB's public-edge IP |
| Firecrawl API + Redis + Playwright | GM | 3 containers; Firecrawl's Redis is internal to it |

Each needs a ship dir, a mesh/internal bind per `docs/runbooks/add-a-service.md`, and an
auth decision. GM mesh IP `100.64.0.1`, TB `100.64.0.2`.

## Verify before trusting

- Firecrawl self-hosted must answer **`/v2/scrape`** — Open-WebUI v0.10.2 speaks v2
  (`firecrawl.py:24-27`) and carries a v1/v2 response-shape shim (issue #23966). Self-host
  also loses Fire-engine, so bot-detection handling is absent.
- SearXNG needs `json` in `search.formats` or Open-WebUI receives HTML.

## For `docs/FUTURE.md`

- **Benchmark the chunking choice** (token, 800/100, markdown pre-pass) against a real
  corpus.
- tiktoken downloads at runtime on slim — matters for an air-gapped company build.
- Fix the `config.env` comment asserting slim ships no local ML stack.
