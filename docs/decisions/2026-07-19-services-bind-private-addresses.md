# Services bind a private address, never 0.0.0.0

**2026-07-19 · Accepted · `c481048`**

Docker publishes past the host firewall: a `0.0.0.0` publish inserts its own DNAT rule
and is reachable from the internet whatever `ufw` says. The rule removes the failure
mode instead of trying to firewall around it.

Every published port binds `127.0.0.1` on TB (Caddy is on the same host) or
`100.64.0.1` on GM (its mesh address, reachable from TB's Caddy, off the public
interface). Only Caddy and Komodo Core use `network_mode: host`, because they must dial
mesh addresses themselves.

**Consequence:** GM services must be ordered `After=tailscaled` — the address doesn't
exist until the mesh is up. Anything needing to reach GM goes over the mesh or through
Caddy. Don't "fix" a bind to `0.0.0.0` to make something reachable.
