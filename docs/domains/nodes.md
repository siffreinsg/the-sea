# Nodes and placement

Four machines, two of them Docker nodes under Komodo. Where a service goes is decided by
the benchmarks below, not by the names.

| Ship | Machine | Role | Runtime |
|---|---|---|---|
| **Thriller Bark** (TB) | Oracle Cloud ARM, 4 vCPU / 24 GB | Control plane + public edge | Docker + Periphery |
| **Going Merry** (GM) | Omgserv OpenVZ VPS, 8 vCPU / 32 GB | DB / disk / RAM box | Docker + Periphery |
| **The Thousand Sunny** | Ultra.cc box, no sudo, no Docker | Media + downloads | Ultra.cc `app-*` services |
| **Baratie** | Raspberry Pi | Home Assistant | HAOS, not Komodo |

**Den Den Mushi** is the alerting system, not a machine — every Telegram or Discord bot
that speaks for this infrastructure. The transponder snail carries messages.

Sunny and Baratie are outside Komodo; this repo versions only helper scripts and docs for
them. Sunny is [deliberately off the mesh](../ADR/2026-07-25-sunny-stays-off-the-mesh.md).

## Hardware and benchmarks

Benchmarked 2026-07-22 — sysbench cpu/mem, fio 4k randrw direct, vmstat steal, mesh ping.
**The headline: TB is CPU-strong but disk-throttled; GM is CPU-modest but disk-excellent.**

| | Thriller Bark | Going Merry |
|---|---|---|
| Kernel / arch | 6.17 `aarch64` (controlled) | 4.19 `x86_64` (provider-controlled) |
| CPU | Ampere Neoverse-N1, 4 vCPU | Xeon E5-2670 @ 2.6 GHz, 8 vCPU |
| Disk | 193 G Oracle block volume | 99 G ploop |
| CPU 1-thread (events/s) | **1280** | 322 |
| CPU all-core (events/s) | **4950** | 2474 |
| Memory bandwidth | 15.2 GiB/s | 16.6 GiB/s |
| **Disk 4k randrw read** | 5.5k IOPS / 22 MB/s | **95k IOPS / 391 MB/s** |
| **Disk 4k randrw write** | 2.4k IOPS / 9.7 MB/s | **41k IOPS / 167 MB/s** |
| CPU steal under load | — | **0%**, not oversold |
| Mesh latency GM↔TB | 1.5 ms, 0% loss | |

## Placement rule

**CPU-bound, latency-sensitive, public-edge and sensitive → TB.**
**Disk-I/O-heavy, DB-backed, RAM-hungry → GM.**

TB's slow disk is hidden by RAM cache for small, warm, single-user working sets. GM's only
real weakness is per-core CPU, so avoid single-thread-latency-critical work there.
Rationale: [placement follows the benchmarks](../ADR/2026-07-22-placement-follows-benchmarks.md).

## Per-node caveats

**Thriller Bark**
- **Disk is the scarce resource** (~2.4k write IOPS). Cap retention on anything
  time-series that stays here.
- Controlled kernel, so this is where sensitive data and the DR root of trust live.
- `unattended-upgrades` installs kernels but **does not reboot** unless
  `Automatic-Reboot` is set — it now is, 02:00. `/var/run/reboot-required` is the check.

**Going Merry**
- **OpenVZ on a provider-controlled kernel.** Standard containers are fine; avoid
  kernel-exotic workloads — a volume plugin using time namespaces once crashed dockerd.
  Its `ifupdown-pre` / `systemd-networkd-wait-online` failures are benign OpenVZ noise.
- Container least-privilege is capped here: no AppArmor, no userns-remap. Accepted.
- **x86_64 while TB is aarch64** — verify multi-arch images before landing on TB.

## Where things run

Control plane: Headscale, Komodo Core, Caddy and Backrest on **TB**; Grafana,
VictoriaMetrics and Loki on **GM**
([why](../ADR/2026-07-23-observability-on-going-merry.md)); Alloy on both.

| TB | GM |
|---|---|
| Authelia, Actual Budget, n8n | Dawarich, your_spotify, Profilarr, Cleanuparr |
| Open-WebUI, LiteLLM, Homepage | PlexAutoLanguages, Wizarr, bazarr |
| Wallos, Syncthing | Karakeep, Forgejo |

Two of those go against the rule on purpose. **Syncthing** is on TB's slow disk because it
is the only node that can hold a
[public listener](../ADR/2026-07-26-syncthing-public-port.md). **Wallos** is on TB
because it is financial data, not because of its load.

Placement intent, not deployment status.
