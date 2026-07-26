# Plan — AI platform: Scaleway → LiteLLM → Open-WebUI / n8n, fully traced

**Roadmap doc, spanning several sessions.** `docs/plans/2026-07-25-llm-stack.md` stays the
deploy-mechanics doc for the LiteLLM and Open-WebUI stacks — ports, binds, OIDC client,
callback paths, the `the-sea-internal` network. **This doc does not restate any of it**;
it sequences the wider programme and holds only what that plan doesn't cover. Read that one
for *how to deploy*, this one for *what order and why*. Both get deleted when the work lands.

**The end state:** a question typed into Open-WebUI, or an LLM node firing inside an n8n
workflow, produces **one trace** in Grafana spanning the app → LiteLLM → Scaleway, with cost
and token counts attached, next to the logs from the same request.

## The shape

```
Open-WebUI ─┐                              ┌─ Scaleway Generative APIs
            ├─→ LiteLLM (gateway, keys, ───┤   (api.scaleway.ai/v1)
n8n ────────┘    budgets, cost tracking)   └─ (future: other providers)
     │                │
     └── OTLP traces ─┴──→ Alloy → Tempo (GM) → Grafana
                                    └── logs already → Loki
```

Unchanged from the original decision: **LiteLLM is the only holder of provider keys.**
Every consumer gets its own virtual key. Open-WebUI and n8n never see `SCW_SECRET_KEY`.

---

## Phase 0 — Scaleway credentials (blocks everything)

**You create the key; I can't.** No browser, no account access, and per the repo's rules I
never hold a secret. The steps:

- Console → **IAM → API keys → Generate API key**, or `scw iam api-key create`.
- It needs a policy granting **`GenerativeApisFullAccess`** (or the read/inference subset)
  on the project you want billed. Scope it to that project, not the whole organisation.
- You get an **access key** and a **secret key**. LiteLLM only needs the secret.
- The secret is shown **once**. Paste it straight into `sops thriller-bark/litellm/secrets.env`
  as `SCW_SECRET_KEY=...` — never onto a command line (`~/.bash_history`, `ps`).

**Verified:** LiteLLM ships a native Scaleway provider — prefix `scaleway/`, env var
`SCW_SECRET_KEY`, base URL `https://api.scaleway.ai/v1`. No custom `openai/`-compatible
shim needed. `config.yaml` names the variable explicitly via `credential_list` rather than
relying on the provider default.

---

## Phase 1 — LiteLLM, for real

**Resolved 2026-07-27 — the fork is closed and Postgres is in.** This section used to
defer the database to Phase 4 and weigh config-file-only against it. That table is gone:
the admin UI *is* the key and spend store, so asking for the UI settled it on day one, and
building the Postgres now is the cheaper order anyway since pgvector needed one regardless.
One `pgvector/pgvector:0.8.5-pg17` on TB, in the LiteLLM stack, no host port —
[decision record](../decisions/2026-07-27-postgres-on-thriller-bark.md).

What that unlocks immediately, and what the rest of this doc no longer needs to hedge
about: per-key budgets, rotatable virtual keys, a queryable spend table, and per-key MCP
permissions in Phase 4. **The Phase 5 cost dashboard is no longer blocked.**
`STORE_MODEL_IN_DB` stays off, so the model list is still committed YAML.

**Model list — written.** `thriller-bark/litellm/config.yaml`, bind-mounted, hence the
`--force-recreate`. Five models, each entry a known-working shape:

| model_name | why |
|---|---|
| `scw-qwen3.6-35b` | cheap and fast; also Open-WebUI's `TASK_MODEL_EXTERNAL` |
| `scw-qwen3.5-397b-a17b` | the strong general model |
| `scw-glm-5.2` | second strong model |
| `scw-whisper-large-v3` | STT. Not voxtral — whisper is the `/v1/audio/transcriptions` model, voxtral is chat-with-audio and won't drop into Open-WebUI's STT |
| `scw-bge-multilingual-gemma2` | embeddings, **fixed 3584 dimensions** |

**The embedding choice was about determinism, not quality.** `qwen3-embedding-8b` is
configurable 32–4096; bge is fixed at 3584, which removes the chance of Phase 4 setting
`PGVECTOR_INITIALIZE_MAX_VECTOR_LENGTH` to something that doesn't match. bge also tops
MTEB for French. **Set that var to 3584 before the first document is indexed.**

**The `api_base` trap, worth keeping.** Only the `scaleway/`-prefixed entries know
Scaleway's base URL. The `openai/...` and `custom_llm_provider: openai` entries are plain
OpenAI-compatible passthrough and would dial `api.openai.com` with a Scaleway key. A
single top-level `credential_list` entry (`credential_name: scaleway`) supplies both
`api_key` and `api_base` to every model, so no per-model `api_base` is needed. Verified
present at v1.93.0 (`proxy_server.py:4026`, `load_credential_list`).


**Pin check on deploy day.** `ghcr.io/berriai/litellm:v1.93.0` was resolved 2026-07-25;
re-verify per the manifest-HEAD recipe in the llm-stack plan (the GHCR tag-list trap is
written up there).

---

## Phase 2 — Tempo, the missing piece — **confirmed, in scope**

**The fleet has no trace store.** `docs/domains/observability.md` is metrics + logs only:
VictoriaMetrics, Loki, Grafana, Alloy. Nothing in the tracing brief works until this exists.
This is the largest single gap in the programme and it is *not* an Open-WebUI or LiteLLM
problem. **Decided 2026-07-26: install it.**

**Add Grafana Tempo to the `observability` stack on GM** — same node as Grafana and Loki,
same mesh bind pattern (`100.64.0.1`), same provisioned-datasource discipline.

- Pin **`grafana/tempo:v3.0.2`** (released 2026-06-09; re-check on the day). GM is
  `x86_64`, so no ARM manifest question — unlike anything landing on TB.
- Retention: match Loki's 30d, or shorter. Traces are bulkier than logs; **start at 7–14d**
  and raise it if you actually go looking. GM is the disk-excellent box, which is why this
  goes there.
- New datasource in `grafana-datasources.yaml`. Provisioned, read-only in the UI, like the
  other two.
- **Not backed up**, consistent with VM and Loki — retention-capped by design.

**Ingest path:** both nodes already run Alloy. Add `otelcol.receiver.otlp` (gRPC 4317 /
HTTP 4318) on TB's Alloy and forward over the mesh to Tempo on GM. That keeps the existing
"one collector per node, apps talk to localhost" shape rather than exposing Tempo to TB.

**Grafana wiring that makes it worth it** — the derived-field links, without which you have
three disconnected panes:
- **Trace → Logs**: Tempo datasource → `tracesToLogsV2` → Loki, matched on trace ID.
- **Logs → Trace**: Loki datasource derived field extracting the trace ID from a log line
  → Tempo. Requires the apps to *log* the trace ID; check what LiteLLM emits.
- **Trace → Metrics** if the span metrics are worth it. Optional, later.

---

## Phase 3 — The trace chain, end to end

**All three hops support this natively. No sidecars, no patching.** This was the biggest
unknown going in and it resolved cleanly:

| hop | mechanism | notes |
|---|---|---|
| **n8n** | `N8N_OTEL_ENABLED=true`, `N8N_OTEL_EXPORTER_OTLP_ENDPOINT=http://<alloy>:4318` | native since **2.19.0**; the fleet runs **2.32.3**, so it's already there |
| **n8n → LiteLLM** | `N8N_OTEL_TRACES_INJECT_OUTBOUND=true` | **this is the correlation key** — injects W3C `traceparent` into outbound HTTP |
| **LiteLLM** | `litellm.callbacks = ["otel"]`, `OTEL_EXPORTER=otlp_http`, `OTEL_ENDPOINT`, `OTEL_SERVICE_NAME` | honours an inbound `traceparent` and parents its span to it |
| **Open-WebUI** | `ENABLE_OTEL=true`, `ENABLE_OTEL_TRACES=true`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME=open-webui` | `OTEL_EXPORTER_OTLP_INSECURE=true` on the mesh — no TLS between our own containers |

LiteLLM's documented parent resolution, highest priority first: explicit
`litellm_parent_otel_span` in metadata → inbound `traceparent` header → active global
context → none (own root). So an n8n workflow span becomes the *parent* of the LiteLLM
span, which is exactly the "how does AI integrate into my workflows" view you're after.

Also set on n8n:
- `N8N_OTEL_TRACES_INCLUDE_NODE_SPANS=true` — per-node spans, so you see *which* node
  called the model.
- `N8N_OTEL_TRACES_PRODUCTION_ONLY=false` — otherwise manual test runs emit nothing, which
  is precisely when you're debugging.
- `N8N_OTEL_TRACES_SAMPLE_RATE` — leave at full for a single-user fleet.

**Done when:** one workflow run in n8n produces a single Grafana trace containing the
workflow span, the node span, the LiteLLM span and the Scaleway call, and clicking that
trace jumps to the matching Loki lines.

**Caveat to test, not assume:** whether Open-WebUI's chat requests propagate context into
LiteLLM the same way. n8n's outbound injection is documented; Open-WebUI's is not. If it
doesn't, Open-WebUI and LiteLLM traces stay siblings rather than parent/child — still
useful, just not one tree. Verify before designing dashboards around it.

---

## Phase 4 — RAG and the sidekick stack

Deferred out of the 2026-07-26 session; this is where it lands. Decisions needed, in order:

1. **Embedding engine** — `RAG_EMBEDDING_ENGINE=openai` pointed at LiteLLM, so embeddings
   go through the same gateway, same key, same cost tracking. `RAG_OPENAI_API_BASE_URL` /
   `RAG_OPENAI_API_KEY` inherit the main OpenAI settings by default. **This also stops the
   local sentence-transformers model loading at `main.py:587`** — currently it loads on
   every boot on TB's ARM CPU whether RAG is used or not.
2. **Vector store — pgvector, and the Postgres already exists.** `VECTOR_DB=pgvector` +
   `PGVECTOR_DB_URL`, over the default embedded Chroma. This used to be "the decision that
   drags Postgres into the fleet"; Phase 1 got there first, on TB, on the pgvector image
   precisely so this phase adds a schema and not a server. Placement is settled and
   recorded; `backup.sh` and the critical plan entry already exist.

   **Embedding dimensions are still load-bearing.**
   `PGVECTOR_INITIALIZE_MAX_VECTOR_LENGTH` defaults to `1536`; the chosen model,
   `bge-multilingual-gemma2`, is **3584**. **Set it before the first document is indexed** —
   changing it later means dropping the index and re-embedding everything at Scaleway's
   per-token rate.

   Still worth measuring: retrieval is chatty, and it now runs on TB's slow disk. If that
   turns out to be what limits RAG, it reopens the placement decision.

3. **Document extraction — Tika, decided.** `CONTENT_EXTRACTION_ENGINE=tika` +
   `TIKA_SERVER_URL`. **Put it on GM**, not TB: extraction is CPU- and RAM-hungry batch work,
   which is exactly what TB (4 vCPU, public edge, latency-sensitive) shouldn't be doing.
   It's an internal service — no Caddy route, no Authelia, mesh bind only, same posture as
   LiteLLM. Check the ARM/x86 manifest anyway if it ever moves.
   Docling is the richer parser but heavier; **start with Tika**, and only revisit if PDF
   quality is actually the thing limiting RAG.

4. **Web search — SearXNG is the leading candidate, but study the free alternatives first.**
   `ENABLE_WEB_SEARCH=False` today. SearXNG self-hosts, needs no API key, and Open-WebUI has
   first-class support (`WEB_SEARCH_ENGINE=searxng` + `SEARXNG_QUERY_URL`). The cost is
   another service to run and keep unblocked by search providers — SearXNG instances get
   rate-limited and its upstreams break quietly.

   **To study before committing** (this is a research task for the session, not a decided
   item):
   - Free/keyless engines Open-WebUI supports natively — **DuckDuckGo (`ddgs`)** needs no
     key at all and is one env var. That may simply be enough, and it's the laziest answer.
   - Free tiers with a key: Brave, Tavily, Mojeek, Exa — one more secret in SOPS each.
   - **Your wacky option: route search through a CLI agent** (Codex / Pi) that has its own
     search tool, exposed to Open-WebUI as a tool or an
     `EXTERNAL_WEB_SEARCH_URL` endpoint. Genuinely interesting — it reuses a subscription
     you already pay for instead of adding a quota. Assess honestly against: latency (an
     agent turn is seconds, not milliseconds), reliability as an unattended dependency,
     whether the ToS covers programmatic use, and how much glue code *you* end up owning.
     A shim you maintain forever is a real cost; write it down before choosing it.

5. **MCP — study, don't assume.** Findings so far, to save a research round:
   - **LiteLLM supports MCP servers natively** — `mcp_servers:` in `config.yaml`, transports
     `http`/`sse`/`stdio`, auth per server, exposed to clients on a single `/mcp` endpoint
     and via the standard `tools` array on `/v1/chat/completions`.
   - **That makes LiteLLM the right place for it**, not Open-WebUI: one tool registry shared
     by Open-WebUI *and* n8n, defined in the same committed config as the model list, with
     the same key discipline. Consistent with why LiteLLM exists at all.
   - **Per-virtual-key MCP permissions are a DB feature** — available, since Phase 1's
     Postgres landed.
   - Still to establish: which MCP servers are actually worth running here, and whether
     Open-WebUI's tool-calling path drives LiteLLM-side MCP cleanly or wants `mcpo` /
     direct connections instead. **Relevance first, plumbing second** — don't build a tool
     registry with nothing worth putting in it.

6. `ENABLE_SEARCH_QUERY_GENERATION` / `ENABLE_RETRIEVAL_QUERY_GENERATION` both default
   `True` and each fires an extra LLM call once the parent feature is on — same class of
   silent cost as the title/tags/follow-up trio already cut. Point them at the cheap model.

**The rest of the sidekick stack is still open.** Confirmed so far: **Tika + pgvector**,
plus **SearXNG-or-alternative** and **MCP** pending study. Each further item is a ship dir,
a Caddy block and an auth decision, so re-scope when the list settles.

---

## Phase 5 — Dashboards and explainability

Only build what answers a question you actually have — `docs/domains/observability.md` is
explicit that no per-service dashboard is required, and 1860/14282 already cover resources.
What's genuinely missing and worth building:

- **Cost per consumer over time** — which of Open-WebUI / n8n / Karakeep is spending, by
  virtual key. **No longer blocked** — Phase 1's Postgres means the spend table is
  populated from the first request, so build this one for real.
- **Latency by model and by hop** — is it Scaleway, the mesh, or LiteLLM's own overhead.
- **Error and rate-limit rate** — Scaleway rate-limits per project; you want to see 429s
  before they become "the chat is broken".
- **A trace-first exploration view**, which is mostly Tempo search rather than a dashboard.

Alerting: worth one rule for provider errors, one for a spend threshold. Both route to the
existing Telegram contact point. Keep them in `rules.yaml` like everything else.

---

## Sequencing

Phase 0 blocks 1. Phase 2 blocks 3. Phase 1 blocks 4 (embeddings need the gateway).
Phase 3 and 4 are independent of each other.

Suggested order: **0 → 1 → 2 → 3 → 4 → 5**, with the Open-WebUI `config.env` from the
2026-07-26 session written during Phase 1, since it's mostly blocked on the LiteLLM
connection vars anyway.

**The Postgres question is closed** — it was re-opened and settled at Phase 1 on
2026-07-27, not deferred to Phase 4. Cost attribution, per-key budgets and per-key MCP
permissions are all available from the start.

## Decisions this will generate

Per AGENTS.md, rationale lives in the decision record, not here:
- Open-WebUI config-as-code / `ENABLE_PERSISTENT_CONFIG=False` (decided 2026-07-26, unwritten).
- **Tempo joining the observability stack**, and its retention — decided 2026-07-26,
  changes a documented layer, so `docs/domains/observability.md` needs updating too.
- Scaleway as the provider, and single-provider vs. multi-provider.
- pgvector over Chroma, and the Postgres placement that follows from it.
- LiteLLM Postgres, if and when Phase 1's deferral is reversed — it would revisit part of
  the 2026-07-25 plan.
- Whichever web-search route wins, **especially if it's the agent-CLI shim** — that one is
  unusual enough that a future clone will want to know why.
