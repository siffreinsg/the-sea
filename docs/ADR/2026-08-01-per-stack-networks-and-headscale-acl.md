# Per-stack Docker networks, bridge-mode Caddy, Headscale ACL

Date: 2026-08-01

## Decision

Replace the flat `the-sea-internal` bridge and host-published loopback/mesh ports with a
per-stack default network per compose project, two purpose-named shared networks (`edge`,
`ai-backends`), a bridge-mode main Caddy plus a dedicated host-mode `gm-relay`, and a
Headscale port-level TB→GM ACL *additional* to the mesh-guard, not a replacement (below).

## Why

The prior model accreted one exception at a time (`the-sea-internal`, three separate
`0.0.0.0` binds, a TB-only iptables guard) until the set no longer read as one coherent
design. Explicit and standard first; generalizing the mesh-guard to both nodes follows
from that. The `0.0.0.0` exception count stays at three — Alloy, `gm-relay`, Syncthing.

## Correction found in final review

The first draft had the ACL *replace* the mesh guard. It can't: the guard acts before
Docker's MASQUERADE rewrites a container's source to the host's tailnet IP, the ACL only
sees packets after. **The guard stays, generalized to both nodes**; the ACL is additive.
Mechanism and the Komodo Core open question: [networking.md § Cross-node
enforcement](../domains/networking.md), [deploy.md § Periphery](../domains/deploy.md).

## Supersedes

- [caddy-relays-mesh-services-to-containers](2026-07-29-caddy-relays-mesh-services-to-containers.md) —
  relay pattern moved into its own `gm-relay` stack.
- [cross-node-calls-use-the-public-edge](2026-07-27-cross-node-calls-use-the-public-edge.md) —
  its LiteLLM reasoning still holds; "guard is TB-only" no longer true, GM has a copy now.

## Extends, does not supersede

[caddy-single-public-edge](2026-07-19-caddy-single-public-edge.md),
[mesh-guard-in-raw-prerouting](2026-07-25-mesh-guard-in-raw-prerouting.md),
[services-bind-private-addresses](2026-07-19-services-bind-private-addresses.md) — all
still true as written; this redesign adds the GM guard copy and renames the relay.
</content>
