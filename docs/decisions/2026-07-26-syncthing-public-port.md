# Syncthing gets a public port, the one exception to the bind rule

**2026-07-26 · Accepted**

Supersedes the "dropped for now" Syncthing entry in [future](../future.md).

Syncthing was dropped because it needs peers to reach 22000, and every service here binds
a private address — `127.0.0.1` on TB, `100.64.0.1` on GM
([the rule](2026-07-19-services-bind-private-addresses.md)). The assumed way out was to
make every sync peer a Tailscale client. At least one machine can't be, so that way out
does not exist.

The alternative that needs no port is Syncthing's public relay pool: peers connect
outbound, traffic stays end-to-end encrypted, no listener anywhere. It was rejected —
relayed sync is slow and routes connection metadata through third parties for a 20 GB
tree that is synced continuously.

**Decision: Syncthing on TB publishes 22000/tcp+udp on `0.0.0.0`. Relaying, global
discovery, local discovery and UPnP are all off.** The GUI stays on `127.0.0.1:8384`
behind `forward_auth` like everything else — the exception covers the sync protocol only.

What makes it acceptable, and what has to stay true:

- The listener speaks BEP over its own TLS, and **a peer is refused unless its device ID
  was confirmed on both ends**. The allowlist, not the firewall, is the boundary here.
- Discovery off means the node does not announce itself; peers carry static addresses.
- It is one port on the node that already terminates public TLS, not a second edge. The
  [one-public-edge decision](2026-07-19-caddy-single-public-edge.md) is about HTTP and is
  not weakened by a non-HTTP listener beside it.

**Consequence:** TB's open ports become **80/443/22/22000**, which needs an Oracle VCN
security-list rule as well as the Docker publish — `docs/reference.md` updated to match.
The bind rule now has exactly one written exception; any second one needs its own record,
not a reference to this one. Syncthing also lands on TB's slow disk against the placement
rule, accepted because the public port has to be here and the write pattern is bursty.
