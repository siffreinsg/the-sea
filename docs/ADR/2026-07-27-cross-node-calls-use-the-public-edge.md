# GM→TB service calls go through the public edge, not the mesh

**2026-07-27 · Superseded by [2026-07-29](2026-07-29-caddy-relays-mesh-services-to-containers.md)**

The public edge is still one of the two sanctioned paths (below still describes why); what
changed is it only applies when the callee authenticates itself.

At the time, `the-sea-mesh-guard.service` ran **TB only**, so GM's bridged containers
could reach `100.64.0.0/10`. The Karakeep plan (bridged, on GM, dialing
`http://100.64.0.2:4000/v1`) would have needed that reachability, which a fleet-wide guard
would have broken.

**Decision: cross-node app→app calls use the public edge.** Karakeep dials
`https://ai.siffreinsigy.me/v1`; LiteLLM's mesh publish is removed, binds `127.0.0.1:4000`
only — no exposure cost, the public edge already served LiteLLM's whole API.
Authentication is unchanged either way: LiteLLM virtual keys, not network position.

GM's guard gap is closed by
[per-stack-networks-and-headscale-acl](2026-08-01-per-stack-networks-and-headscale-acl.md).
