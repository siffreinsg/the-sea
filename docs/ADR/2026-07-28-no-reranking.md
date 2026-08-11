# RAG uses no reranker

**2026-07-28 · Accepted**

A CPU cross-encoder was deployed on GM (Infinity + `BAAI/bge-reranker-v2-m3`) and measured
before use. It needs minutes per call at `RAG_TOP_K=40`, and TB is only ~2x GM all-core
([benchmarks](../domains/nodes.md)) against a gap of ~100x, so moving it does not help.
Measured 2026-07-28: 45 min cold start, one core used, a realistic 32k-token call never
returned. A smaller cross-encoder was rejected
because it re-opens the quality argument that ruled out Scaleway's endpoint, and a hosted
reranking API because it sends document text to a third party.

Retrieval is now hybrid search alone: pgvector cosine fused with BM25.

Consequences:

- `RAG_TOP_K` drops 40 → 8. It was wide only because a reranker narrowed it.
- Retrieval quality on noisy sources, web search especially, is worse than the design
  assumed. By how much is unmeasured.
- Self-hosted reranking is viable again only on different hardware.
