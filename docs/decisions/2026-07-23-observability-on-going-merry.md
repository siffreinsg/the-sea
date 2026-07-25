# The observability stack runs on Going Merry

**2026-07-23 · Accepted · `f1dd185`**

VictoriaMetrics and Loki are write-heavy time-series stores, which is precisely the
workload TB's ~2.4k write IOPS punishes and GM's ~41k handles comfortably. A live
migration moved the stack rather than leaving it where it was first built.

**Consequence:** monitoring now dies with GM — the node being watched hosts the watcher
for the other one. Softened by external node-liveness from Uptime-Kuma on Sunny, and by
capping retention regardless (metrics 90d, logs 30d; neither is backed up). Grafana is
still reached at `grafana.siffreinsigy.me` through TB's Caddy, proxied over the mesh.
