# Placement follows the benchmarks, not the labels

**2026-07-22 · Accepted · `8844989`**

The original spec called TB the workhorse and GM the light node. Benchmarking (sysbench,
fio 4k randrw, vmstat steal) showed that framing is wrong: TB has ~4× the per-core CPU
but its disk is ~17× slower, and GM shows 0% steal under full load — it is not oversold.

The rule of thumb is now: **CPU-bound, latency-sensitive, public-edge and sensitive → TB;
disk-I/O-heavy, DB-backed, RAM-hungry → GM.**

**Consequence:** two immediate moves — Dawarich (postgis, large import) and the whole
observability stack went to GM. TB keeps the edge, Authelia, n8n, Actual and the LLM
gateway. Numbers and caveats in [nodes](../domains/nodes.md).
