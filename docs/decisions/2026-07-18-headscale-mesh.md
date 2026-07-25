# Headscale for the mesh

**2026-07-18 · Accepted · `f03bede`** — supersedes a WireGuard hub-and-spoke design (`b835c48`)

The first design wired the nodes together with hand-rolled WireGuard: a
`bootstrap-wireguard.sh`, `hosts.snippet` files per node, and a hub-and-spoke topology
maintained by hand. Every new node meant editing peer lists on every existing node.

Headscale is a self-hosted Tailscale control plane: nodes authenticate to it, get
addresses from `100.64.0.0/10`, and NAT traversal, key rotation and peer discovery come
for free. It runs on TB behind Caddy.

**Consequence:** the mesh has a control plane that must itself be backed up — Headscale's
`db.sqlite` and `noise_private.key` are DR-critical. GM's `100.64.0.1` is a DB-persisted
pin: never delete the node, re-register it. The WireGuard scripts and snippets are gone.
