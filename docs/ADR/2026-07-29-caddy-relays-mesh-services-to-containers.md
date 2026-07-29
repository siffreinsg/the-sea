# Caddy relays GM services to TB containers, on a non-public listener

**2026-07-29 · Accepted · supersedes [2026-07-27](2026-07-27-cross-node-calls-use-the-public-edge.md)**

That ADR said cross-node app→app calls use the public edge. It holds when the callee
authenticates itself — Karakeep dials `https://ai.siffreinsigy.me` and LiteLLM's virtual
keys are the gate. SearXNG has no authentication of any kind, so publishing it would put an
open metasearch on the internet, and the [mesh guard](2026-07-25-mesh-guard-in-raw-prerouting.md)
drops any bridged TB container that tries `100.64.0.1` directly.

**Decision: two sanctioned paths, picked by whether the callee can authenticate.** Callee
has its own auth → public edge. Callee has none → a Caddy listener that is not part of the
`*.siffreinsigy.me` site, reverse-proxying to the mesh address. Caddy is `network_mode:
host`, so its traffic is the host's and the guard never sees it. This is the shape
[Alloy already uses for OTLP](../domains/observability.md): bridged containers reach
host-network infrastructure, which reaches the mesh.

Rejected: an ACCEPT hole in the guard for one destination port. It turns a flat invariant
into a per-service allowlist inside a hand-installed unit, and the guard is the control
that stopped n8n reading GM's unauthenticated VictoriaMetrics and Loki.

**Consequences:**

- Caddy binds `0.0.0.0:8090` (SearXNG) and `:8091` (Firecrawl, reserved). Senders sit on
  two different bridges and gateway IPs move when a network is recreated, so a literal
  gateway address is not an option. **Third exception to never-bind-`0.0.0.0`**; the
  perimeter firewall is the gate, exactly as for Alloy's OTLP receiver.
- Bridged containers still never touch the tailnet, so the guard can still be copied to GM.
- Every TB container can reach the relay, and therefore SearXNG. Not VictoriaMetrics, not
  Loki: the relay is an allowlist of one backend per port.
