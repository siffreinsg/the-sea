# The container/tailnet block lives in raw/PREROUTING

**2026-07-25 · Accepted · `37ff039`**

Docker's per-bridge MASQUERADE plus Tailscale's `ts-forward` accept let every bridged
container on TB reach `100.64.0.0/10` — proven from inside n8n, which pulled
unauthenticated 200s from GM's VictoriaMetrics and Loki.

The obvious fix, a REJECT in `DOCKER-USER`, **does not work**: `FORWARD` jumps to
`ts-forward` before `DOCKER-USER`, so Tailscale accepts the packets first. Both daemons
insert their jump at position 1, so the order is whoever restarted last. `raw/PREROUTING`
is the first netfilter hook and neither daemon can get ahead of it.

**Consequence:** a Headscale ACL cannot substitute — the masquerade rewrites the source
to TB's own tailnet IP, so GM cannot distinguish container traffic from host traffic.
DROP rather than REJECT, since REJECT exists only in `filter`. The unit carries
`PartOf=docker.service` because Docker flushes its chains on every start.
