# Per-stack Docker networks, bridge-mode Caddy, Headscale ACL

Date: 2026-08-01

## Decision

Replace the flat `the-sea-internal` bridge and host-published loopback/mesh ports with:
a per-stack default network for every compose project, two purpose-named shared networks
(`edge`, `ai-backends`), a bridge-mode main Caddy plus a dedicated host-mode `gm-relay`
for the one job that still needs the mesh directly, and a Headscale port-level TB→GM ACL
as an *additional* layer alongside the mesh-guard, not a replacement for it — the ACL
can't do the guard's job (see the correction below).

## Why

The prior model accreted one exception at a time (`the-sea-internal`, three separate
`0.0.0.0` binds, a TB-only iptables guard) until the set no longer read as one coherent
design. Explicit and standard first; the security improvement (generalizing the
mesh-guard to both nodes) follows from that, not chased separately. The `0.0.0.0`
exception count stays at three — Alloy, `gm-relay`, Syncthing — same as before this
redesign, just renamed where the mesh-relay pattern became its own stack.

## Correction found in final review

The original design (this ADR's first draft, and the plan it recorded) intended the
Headscale ACL to *replace* `the-sea-mesh-guard.service`, reasoning that a port-level
allowlist covers the same threat. It does not: the guard blocks bridged-container traffic
in `raw/PREROUTING`, before Docker's MASQUERADE rewrites the source to the host's own
tailnet IP. Once that rewrite has happened, Headscale — and any ACL it enforces — cannot
tell a container's traffic from the host's. The two mechanisms defend different things:
the guard blocks the container path, the ACL is a port policy for the host's own
mesh-native traffic (Alloy, gm-relay, Komodo, backups). **The guard stays, generalized to
both nodes** (previously TB-only, which is the asymmetry this redesign closes); the ACL
is additive defense-in-depth, not a substitute.

Similarly, the design's first draft tried to close the `0.0.0.0` exception list down to
zero by binding Alloy's OTLP receiver and `gm-relay`'s loopback listeners to fixed
per-sender addresses. This doesn't work: `host.docker.internal` resolves to one address
per container regardless of which bridge network it's on, so a fixed-address-per-sender
scheme has no way for every sender to actually reach it. Both keep `0.0.0.0`, same
reasoning as before this redesign — the perimeter firewall and (for cross-node hops) the
mesh guard are the compensating control, not the bind address.

## Supersedes

- `docs/ADR/2026-07-19-caddy-single-public-edge.md` — Caddy is no longer the only
  ingress; `gm-relay` is a second, host-mode instance with a narrower job.
- `docs/ADR/2026-07-29-caddy-relays-mesh-services-to-containers.md` — the relay pattern
  is generalized into its own `gm-relay` stack instead of living inside main Caddy.
- `docs/ADR/2026-07-27-cross-node-calls-use-the-public-edge.md` — the LiteLLM-specific
  reasoning in that ADR still holds; the general mechanism it described (Caddy dialing
  `100.64.0.1` directly) is what `gm-relay` replaces.

## Extends, does not supersede

- `docs/ADR/2026-07-25-mesh-guard-in-raw-prerouting.md` — still the live mechanism and
  still the reason it lives in `raw/PREROUTING`; this redesign only adds the GM copy.
- `docs/ADR/2026-07-19-services-bind-private-addresses.md` — still true, exception list
  unchanged in count (Alloy, gm-relay's loopback proxies, Syncthing), gm-relay is the new
  name for what was "Caddy's relay listeners."
</content>
