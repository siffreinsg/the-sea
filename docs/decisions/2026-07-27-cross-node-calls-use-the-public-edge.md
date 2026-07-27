# GM→TB service calls go through the public edge, not the mesh

**2026-07-27 · Accepted**

`networking.md` states *"containers must not reach the tailnet"* as a fleet property, but
`the-sea-mesh-guard.service` runs on **TB only**. GM's bridged containers can reach
`100.64.0.0/10` today. That was survivable while nothing on GM needed to, and the guard's
actual threat — a user-code engine, n8n — lives on TB.

The Karakeep plan broke that. It had Karakeep (bridged, on GM) dial
`http://100.64.0.2:4000/v1`, which is by definition the thing the guard forbids. Installing
the guard on GM would have broken Karakeep on the day it shipped, so the invariant could
never have been made fleet-wide.

**Decision: cross-node app→app calls use the public edge.** Karakeep dials
`https://ai.siffreinsigy.me/v1`. LiteLLM's `100.64.0.2:4000` publish is removed; it binds
`127.0.0.1:4000` only. This costs nothing in exposure — `ai.siffreinsigy.me` already
reverse-proxies LiteLLM's whole API publicly (`/metrics` 404'd), so the mesh bind was
strictly the smaller surface, not the larger one, and removing it changes no reachability
that mattered.

**Consequence:** the mesh stays what `networking.md` says it is — a transport for
*infrastructure* (Alloy→GM, Caddy→GM's service binds, both `network_mode: host` and
unaffected by the guard), not for bridged application containers. GM can therefore take a
copy of the mesh guard whenever we want it, with no service to break. **That install has
not happened** — GM's exemption is still live and is now a known gap rather than an
unrecorded one.

Authentication is unchanged either way: LiteLLM virtual keys, not network position.
