# Runbooks

What to type. Procedures that get run again, possibly under pressure. One file per
procedure, named `<verb-object>.md`. Why anything works the way it does lives in
[domains/](../domains/), not here.

| | |
|---|---|
| [add-a-service](add-a-service.md) | The full pattern for a new service |
| [deploy-a-stack](deploy-a-stack.md) | Manual deploy fallback, and the Caddy rebuild |
| [handle-secrets](handle-secrets.md) | sops encrypt/decrypt, hashes, file-mode audit |
| [db-dumps](db-dumps.md) | The nightly dump harness, installing it, verifying a run |
| [check-the-mesh](check-the-mesh.md) | Headscale, preauth keys, the container/tailnet guard |
| [query-observability](query-observability.md) | VM/Loki queries, Grafana export, volume-size collector |
| [check-node-health](check-node-health.md) | Reboots, upgrades, what is listening |
