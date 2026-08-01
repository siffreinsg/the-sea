# Per-stack Docker networks, bridge-mode Caddy, Headscale ACL

Date: 2026-08-01

## Decision

Replace the flat `the-sea-internal` bridge, host-published loopback/mesh ports, and the
TB-only mesh-guard with: a per-stack default network for every compose project, two
purpose-named shared networks (`edge`, `ai-backends`), a bridge-mode main Caddy plus a
dedicated host-mode `gm-relay` for the one job that still needs the mesh directly, and a
Headscale port-level TB→GM ACL applied identically to both nodes.

## Why

The prior model accreted one exception at a time (`the-sea-internal`, three separate
`0.0.0.0` binds, a TB-only iptables guard) until the set no longer read as one coherent
design. Explicit and standard first; the security improvement (closing the GM mesh-guard
gap, shrinking the `0.0.0.0` exception list) follows from that, not chased separately.

## Supersedes

- `docs/ADR/2026-07-19-caddy-single-public-edge.md` — Caddy is no longer the only
  ingress; `gm-relay` is a second, host-mode instance with a narrower job.
- `docs/ADR/2026-07-25-mesh-guard-in-raw-prerouting.md` — the guard is deleted, replaced
  by the Headscale ACL.
- `docs/ADR/2026-07-29-caddy-relays-mesh-services-to-containers.md` — the relay pattern
  is generalized into its own `gm-relay` stack instead of living inside main Caddy.
- `docs/ADR/2026-07-19-services-bind-private-addresses.md` — still true, but the
  `0.0.0.0` exception list shrinks from three to two (Alloy moves to fixed gateway IPs;
  Syncthing unchanged).
- `docs/ADR/2026-07-27-cross-node-calls-use-the-public-edge.md` — the LiteLLM-specific
  reasoning in that ADR still holds; the general mechanism it described (Caddy dialing
  `100.64.0.1` directly) is what `gm-relay` replaces.
</content>
