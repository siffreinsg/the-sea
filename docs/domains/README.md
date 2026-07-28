# Domains

How each layer works, and the rules that keep it working. Rationale lives in
[ADR/](../ADR/); these docs state the rule and link it. Overview and diagram:
[ARCHI.md](../ARCHI.md).

| | |
|---|---|
| [nodes](nodes.md) | The four machines, benchmarks, placement rule |
| [networking](networking.md) | Mesh, binds, firewall, DNS |
| [ingress](ingress.md) | Caddy edge, TLS, the three auth outcomes |
| [secrets](secrets.md) | SOPS + age, file modes, blast radius |
| [deploy](deploy.md) | Komodo sync, Periphery, the inode trap, control-plane updates |
| [backups](backups.md) | Plan assignments, restic, disaster recovery |
| [observability](observability.md) | Metrics, logs, dashboards, alerting |
