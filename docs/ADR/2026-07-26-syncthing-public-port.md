# Syncthing gets a public port, the one exception to the bind rule

**2026-07-26 · Accepted**

Supersedes the "dropped for now" Syncthing entry in [future](../FUTURE.md).

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
discovery, local discovery and UPnP are all off.** GUI stays on `127.0.0.1:8384` behind
`forward_auth`; the exception covers the sync protocol only. The listener speaks BEP over
its own TLS and **refuses a peer unless its device ID was confirmed on both ends** — the
allowlist, not the firewall, is the boundary. Discovery off means the node doesn't
announce itself; peers carry static addresses.

**Consequence:** TB's open ports become **80/443/22/22000** (Oracle VCN rule + Docker
publish, `docs/REFERENCE.md`). The only *publicly reachable* exception to the bind rule —
Alloy's `0.0.0.0` is host-local behind the perimeter firewall, a different thing. Lands on
TB's slow disk against the placement rule, accepted: the public port has to be here.
