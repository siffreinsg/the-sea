# Node performance & characteristics

Benchmarked 2026-07-22 (sysbench cpu/mem, fio 4k randrw direct, vmstat steal, mesh
ping). Use this to decide placement. **The headline: the old "TB = workhorse, GM =
light node" framing is wrong — TB is CPU-strong but disk-throttled, GM is CPU-modest
but disk-excellent.**

## Hardware

| | Thriller Bark (TB) | Going Merry (GM) |
|---|---|---|
| Provider | Oracle Cloud (ARM) | Omgserv (OpenVZ) |
| Kernel / arch | 6.17 `aarch64` (controlled) | 4.19 `x86_64` (provider-controlled) |
| CPU | Ampere Neoverse-N1, 4 vCPU | Xeon E5-2670 @ 2.6 GHz, 8 vCPU |
| RAM | 23 GiB | 32 GiB |
| Disk | 193 G (Oracle block vol) | 99 G (ploop) |
| Role | Control plane + public edge | DB / disk / RAM box |

## Benchmarks

| Metric | TB | GM | Notes |
|---|---|---|---|
| CPU 1-thread (events/s) | **1280** | 322 | TB ~4× per-core |
| CPU all-core (events/s) | **4950** | 2474 | TB 2× with half the cores |
| Memory bandwidth | 15.2 GiB/s | 16.6 GiB/s | ~equal |
| **Disk 4k randrw read** | 5.5k IOPS / 22 MB/s | **95k IOPS / 391 MB/s** | GM ~17× |
| **Disk 4k randrw write** | 2.4k IOPS / 9.7 MB/s | **41k IOPS / 167 MB/s** | GM ~17× |
| CPU steal under full load | — | **0%** | GM **not** oversold |
| Mesh latency GM↔TB | 1.5 ms, 0% loss | | reverse-proxy/mount friendly |

## Placement rule of thumb

- **→ TB:** CPU-bound, latency-sensitive/interactive, public-edge, and **sensitive**
  workloads (controlled kernel). Its slow disk is hidden by RAM cache for small,
  warm, single-user working sets.
- **→ GM:** disk-I/O-heavy, DB-backed, RAM-hungry workloads. Its only weakness is
  weak per-core CPU, so avoid single-thread-latency-critical work here.

Current consequences: Dawarich (postgis + big import) and the observability stack
(VM/Loki, write-heavy time-series) → **GM**. LLM gateway, Authelia, n8n, Actual,
edge → **TB**.

## Operational caveats (carry into any placement)

- **TB disk is the scarce resource** (~2.4k write IOPS). Watch write-heavy services
  here; cap retention on anything time-series that stays on TB.
- **GM is OpenVZ on a provider-controlled kernel.** Standard containers are fine;
  avoid kernel-exotic workloads (a volume plugin using time-namespaces once crashed
  dockerd). Its `ifupdown-pre`/`systemd-networkd-wait-online` failures are benign.
- **GM services bind `100.64.0.1`** (tailscale IP) and must order `After=tailscaled`.
  That IP is a DB-persisted pin — **never delete the node**.
- **GM is x86_64, TB is aarch64** — verify multi-arch images before landing on TB.
- Reliability: TB has the controlled kernel; keep the DR root-of-trust and most
  sensitive data there. External node-liveness is covered by Uptime-Kuma on Sunny.
