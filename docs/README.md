# Docs

| Where | What |
|---|---|
| [`reference.md`](reference.md) | Constants — addresses, ports, schedules, URLs, repo paths |
| [`decisions/`](decisions/) | **Why** things are the way they are. One file per decision |
| [`domains/`](domains/) | **How** each layer works, and the rules that keep it working |
| [`runbooks/`](runbooks/) | **What to type** — repeatable procedures |
| [`plans/`](plans/) | In-flight app deployments. Deleted when the app lands |
| [`future.md`](future.md) | Deferred decisions, deferred plans, tool wishlist |
| [`legacy/`](legacy/) | Pre-Komodo inventory, kept for redeploy reference |

## Domains

| | |
|---|---|
| [nodes](domains/nodes.md) | The four machines, benchmarks, placement rule |
| [networking](domains/networking.md) | Mesh, binds, firewall, DNS |
| [ingress](domains/ingress.md) | Caddy edge, TLS, the three auth outcomes |
| [secrets](domains/secrets.md) | SOPS + age, file modes, blast radius |
| [deploy](domains/deploy.md) | Komodo sync, Periphery, the inode trap, control-plane updates |
| [backups](domains/backups.md) | Plan assignments, restic, disaster recovery |
| [observability](domains/observability.md) | Metrics, logs, dashboards, alerting |

## Runbooks

| | |
|---|---|
| [add-a-service](runbooks/add-a-service.md) | The full pattern for a new service |
| [db-dumps](runbooks/db-dumps.md) | The nightly dump harness, and installing it |
| [commands](runbooks/commands.md) | Commands you run often |

Session state — what is in flight right now — lives in `docs/HANDOFF.md`, which is
untracked on purpose. Anything a fresh clone would need belongs
[here instead](decisions/2026-07-25-operating-rules-versioned.md).
