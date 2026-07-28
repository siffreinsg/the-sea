# CPU cross-encoder throughput on the fleet

Measured 2026-07-28 on GM (Xeon E5-2670, 8 vCPU) with Infinity `0.0.77-cpu` serving
`BAAI/bge-reranker-v2-m3` (568M params, torch engine, bettertransformer on).

Numbers, so this never has to be re-derived:

- Infinity's own startup benchmark: **5713 ms** for `batch_size=32` at ~2 tokens/sentence,
  5.6 embeddings/sec. That is ~64 tokens of real work.
- Cold start, container up to `Application startup complete`: **45 minutes**. Most of it is
  the batch-size search, silent in the logs the whole time. It looks exactly like a hang.
- Only **one core** is ever used. No `OMP_NUM_THREADS` is set anywhere; the likely cause is
  the bettertransformer nested-tensor path, which is prototype and largely single-threaded.
  Never confirmed, since the model was dropped before it mattered.
- A realistic call, 40 documents of ~800 tokens, is ~32,000 tokens: several hundred times
  the benchmark. Ran for minutes without returning; killed rather than timed.

TB would not have saved it. TB is ~2x GM all-core (4950 vs 2474 events/s,
[nodes](../domains/nodes.md)) against a gap of ~100x.

Two API traps found on the way, both cost a round trip:

- Infinity serves **`/rerank`**, not `/v1/rerank` — and `/embeddings`, not `/v1/embeddings`.
  `curl -s http://host:7997/openapi.json | jq -r '.paths | keys[]'` is the source of truth.
- LiteLLM's `infinity/` provider appends `/rerank` to `api_base`, so an `api_base` ending
  in `/v1` yields a 404 that looks like a model problem.

Outcome: [no reranker](../ADR/2026-07-28-no-reranking.md).
