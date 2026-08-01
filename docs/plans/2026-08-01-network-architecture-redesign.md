# Plan — Network architecture redesign

Design notes ahead of the implementation plan. Delete this doc when it lands (the
durable facts move to domain docs and new/superseded ADRs, per docs-system).

## Problem

The current model (flat `the-sea-internal` bridge, per-service loopback/mesh binds,
allow-all Headscale, a TB-only iptables mesh-guard, three separate `0.0.0.0` bind
exceptions) accreted one exception at a time. Each was individually justified but the
set no longer reads as one coherent design. This redesign starts from a standard,
explicit shape and supersedes the ADRs it replaces rather than patching around them.

Priority order: explicit and standard first, security improvement as the result of
that, not a separate goal chased independently.

## Scope

TB and GM container networking, inter-node (mesh) traffic, and host bind policy.
Converted in one pass, both nodes, including GM despite its legacy/OpenVZ status.
Host security hardening (bot protection) and Grafana IP/anomaly dashboards are
separate specs, out of scope here.

## Architecture

### Per-stack Docker networks

Every compose project gets its own named, dynamic-IP bridge network. Isolated by
default — no cross-talk unless two stacks explicitly need it, in which case the
services that need to talk join a common named network (Docker DNS resolves by
container/service name regardless of assigned IP; no static addressing needed for
this). This generalizes the `revproxy`-style shared-network pattern already in use
informally.

An `edge` network carries every TB service Caddy reverse-proxies to directly (see
below).

### Caddy

Host-mode is justified by exactly one thing: the Tailscale interface (`100.64.x.x`)
lives in the host's network namespace, and only a host-mode container can route to it.
Nothing else — not TLS termination, not Authelia forward_auth, not port 443 —
requires host mode; standard Docker port publishing works fine on a bridge network.

Split by destination, not by function:

- **Caddy** (bridge-networked, joins `edge`, publishes `80`/`443` normally): every
  TB-local hostname, including Authelia forward_auth. Proxies by container DNS name.
  No host-published port needed for any TB service — services on `edge` are reached
  by name, not by loopback port.
- **GM relay** (`network_mode: host`, not itself publicly exposed): the only
  mesh-facing component. One site block per GM-bound hostname, each
  `reverse_proxy 100.64.0.1:<port>`, listening on a single `127.0.0.1:<port>`. Same
  shape as today's SearXNG/Playwright relay listeners, generalized to cover every
  GM-bound hostname instead of just the two unauthenticated ones. Caddy forwards
  GM-bound requests to this one loopback port.

This replaces every current per-GM-service Caddy block that dials `100.64.0.1:<port>`
directly from the main Caddy — that direct dial only worked because Caddy was fully
host-mode. Now it's the GM relay's job exclusively.

### Headscale ACL

Today: no ACL, tailnet is allow-all between TB and GM. Replaced with a port-level
allowlist, unidirectional TB→GM (repo inventory found no GM→TB traffic anywhere):

| Service | Port | Proto |
|---|---|---|
| VictoriaMetrics remote_write | 8428 | tcp |
| Loki push | 3100 | tcp |
| Tempo OTLP gRPC | 4317 | tcp |
| Dawarich | 3200 | tcp |
| Backrest-GM | 9898 | tcp |
| Grafana | 3000 | tcp |
| Profilarr | 6868 | tcp |
| Cleanuparr | 11011 | tcp |
| your_spotify | 8095 | tcp |
| SearXNG | 8080 | tcp |
| Playwright | 3002 | tcp |

Komodo Periphery is excluded: onboarding today is outbound-only (GM dials out over the
public edge), no inbound mesh listener is active. Add a rule when/if that flips to
inbound.

This ACL is the sole cross-node enforcement mechanism, replacing
`thriller-bark/firewall/the-sea-mesh-guard.service` (TB-only iptables DROP in
raw/PREROUTING). Applying identically to both nodes closes the documented GM gap
(GM's bridged containers can currently reach the full mesh; TB's can't) as a
consequence of the mechanism change, not a ported unit.

### Host binds

Static subnets are reserved only where a *host*-bound listener must accept
connections from containers on multiple different bridge networks — not for
container-to-container traffic, which stays fully dynamic:

- **Alloy OTLP receiver** (`0.0.0.0:4317/4318` today): stack networks that send OTLP
  get a fixed subnet each; Alloy binds each specific gateway IP instead of the
  catch-all.
- **Syncthing's public 22000**: out of scope, already its own ADR
  (`2026-07-26-syncthing-public-port.md`), unrelated to inter-container reachability.

`127.0.0.1` on TB / `100.64.0.1` on GM remains the default bind for anything that
still needs a host-published port (the GM relay's loopback listeners). Every other
service drops its host-published port entirely in favor of DNS on its stack network.

## Migration

One pass, both nodes, all compose files. Superseded ADRs get a line each in the new
ADR pointing back at what changed and why; not rewritten in place.

## Open items for the plan phase

- Concrete subnet ranges for the reserved (static) networks — pick a block, document
  in REFERENCE.md.
- Exact list of which stacks share `edge` vs. get fully isolated (derive from which
  hostnames Caddy currently proxies).
- Order of operations for a one-pass cutover that doesn't take the edge down mid-work
  (likely: stand up new networks alongside old, cut Caddy over stack by stack within
  the same PR, remove old bridge/ports last).
