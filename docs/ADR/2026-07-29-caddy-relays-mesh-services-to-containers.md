# Caddy relays GM services to TB containers, on a non-public listener

**Superseded by [2026-08-01](2026-08-01-per-stack-networks-and-headscale-acl.md)** — the relay pattern moved into its own `gm-relay` stack; this ADR's `:8090`/`:8091` listeners on main Caddy no longer exist.

**2026-07-29 · Accepted · supersedes [2026-07-27](2026-07-27-cross-node-calls-use-the-public-edge.md)**

That ADR said cross-node app→app calls use the public edge. It holds when the callee
authenticates itself — Karakeep dials `https://ai.siffreinsigy.me` and LiteLLM's virtual
keys are the gate. SearXNG has no authentication of any kind, so publishing it would put an
open metasearch on the internet, and the [mesh guard](2026-07-25-mesh-guard-in-raw-prerouting.md)
drops any bridged TB container that tries `100.64.0.1` directly.

**Decision: two sanctioned paths, picked by whether the callee can authenticate.** Callee
has its own auth → public edge. Callee has none → a Caddy listener outside the
`*.siffreinsigy.me` site, reverse-proxying to the mesh address, `network_mode: host` so
the guard never sees its traffic — same shape as
[Alloy's OTLP path](../domains/observability.md).

Rejected: an ACCEPT hole in the guard for one destination port — turns a flat invariant
into a per-service allowlist, and the guard is what stopped n8n reading GM's
unauthenticated VictoriaMetrics and Loki.

Consequences (mechanism superseded by `gm-relay`, see header): third `0.0.0.0` exception,
gate is the perimeter firewall + tailnet ACL, own devices on `tailscale0` accepted; the
relay is an allowlist of one backend per port, not a general mesh hole.
