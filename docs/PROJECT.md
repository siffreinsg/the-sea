# the-sea

Infrastructure-as-code for a self-hosted homelab run by one person across four machines.
Komodo pulls this repo onto each node and runs the compose stacks, so the repo is the only
source of truth: a node can be rebuilt from it plus the age key.

## Constraints

- Four heterogeneous nodes, not a cluster: Oracle ARM free tier, an OpenVZ VPS, a managed
  Ultra.cc box with no Docker, and a Raspberry Pi running HAOS. Placement rules in
  [domains/nodes.md](domains/nodes.md).
- One public door. Caddy on Thriller Bark, Let's Encrypt via Cloudflare DNS-01.
  Everything else binds loopback or mesh.
- Secrets live encrypted in the repo (SOPS + age). Nothing decrypted ever lands.
- Single operator. A procedure that needs a second person is a procedure that will not run.

## Non-goals

- No high availability, no orchestrator, no Kubernetes. A node down is an outage, not a failover.
- No multi-tenancy. Authelia carries one user; sharing is per-service, not per-identity.
- Not a general-purpose PaaS. Services are added deliberately, each with a domain doc entry.
- No public exposure beyond Caddy and the one Syncthing port.

## Done

The current phase is finished when every heading in [TODO.md](TODO.md) is cleared, which
means:

- Grafana collects from all four nodes without gaps, and its noise is filtered.
- The AI platform serves search and RAG without a broken dependency pinned to a bad tag.
- The Actual Budget rule pipeline runs end to end, from ported rules to LLM leftovers.
- The edge has been scanned from off-network, not through hairpin NAT.

## Docs

- [ARCHI.md](ARCHI.md) — how the pieces fit, entry point to [domains/](domains/)
- [REFERENCE.md](REFERENCE.md) — addresses, ports, schedules, paths
- [TODO.md](TODO.md) — what's next
- [ADR/](ADR/) — why a choice was made
- [runbooks/](runbooks/) — what to type
- [FUTURE.md](FUTURE.md) — ideas, not on deck
