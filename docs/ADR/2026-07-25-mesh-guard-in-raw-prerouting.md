# The container/tailnet block lives in raw/PREROUTING

**2026-07-25 · Accepted · `37ff039`**

Docker's per-bridge MASQUERADE plus Tailscale's `ts-forward` accept let every bridged
container on TB reach `100.64.0.0/10` — proven from inside n8n, which pulled
unauthenticated 200s from GM's VictoriaMetrics and Loki.

The obvious fix, a REJECT in `DOCKER-USER`, **does not work**: `FORWARD` jumps to
`ts-forward` before `DOCKER-USER`, so Tailscale accepts the packets first. Both daemons
insert their jump at position 1, so the order is whoever restarted last. `raw/PREROUTING`
is the first netfilter hook and neither daemon can get ahead of it.

**Amended 2026-08-06:** the rule must match connection initiation only (`-p tcp --syn`,
plus a `-p udp` rule), not the blanket `172.16.0.0/12 -> 100.64.0.0/10`. Before conntrack
there is no direction, so a blanket DROP eats each container's replies too — invisible on
TB, which publishes on `127.0.0.1`, and a full outage on GM, which publishes on
`100.64.0.1`. GM's guard took every published service down for hours and left no counter
in `nat` or `filter` to find it by.

**Consequence:** a Headscale ACL cannot substitute — the masquerade rewrites the source
to TB's own tailnet IP, so GM cannot distinguish container traffic from host traffic.
DROP rather than REJECT, since REJECT exists only in `filter`. The unit carries
`PartOf=docker.service` because Docker flushes its chains on every start.
