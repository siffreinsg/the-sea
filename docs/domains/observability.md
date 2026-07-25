# Observability

Grafana + VictoriaMetrics + Loki on **GM**
([why GM](../decisions/2026-07-23-observability-on-going-merry.md)), one **Alloy**
collector per node pushing over the mesh. Reached at `grafana.siffreinsigy.me` through
TB's Caddy.

- **VictoriaMetrics** — metrics, 90d retention (VM flag).
- **Loki** — logs, 30d retention (`loki.yaml`), `auth_enabled: false`.
- **Alloy** — scrapes container and host metrics, tails logs. Discovers **all** containers
  via docker.sock with no allowlist, so a new service is collected automatically:
  logs land as `{container="<app>"}`, container metrics via cadvisor, both labelled
  `node=<node>`.

Neither VM nor Loki is backed up (retention-capped by design); `grafana-data` is.
Neither has authentication — they bind the mesh and rely on it being trusted, which is why
[containers must not reach the tailnet](networking.md).
Alloy's privilege is the fleet's widest; the honest blast radius is in [secrets](secrets.md).

## Provisioned as code

Datasources, dashboards and alert rules are all provisioned from files bind-mounted into
the Grafana container:

- `provisioning/datasources/grafana-datasources.yaml` — VictoriaMetrics (default) and Loki.
  They address each other by **compose service DNS**, not the mesh IP; the stack moves as a
  unit, and service DNS sidesteps the hairpin-NAT problem.
- `provisioning/dashboards/dashboards.yaml` → `dashboards/nodes.json` (1860, node_exporter)
  and `dashboards/containers.json` (14282, cadvisor).
- `provisioning/alerting/rules.yaml` and `contact-points.yaml`.

**Provisioned resources are read-only in the UI.** Edit the file and redeploy. Grafana
matches by UID on startup, so it takes over previously UI-created resources rather than
duplicating them. Dashboards re-poll every 30s; alert rules only re-read on container start.

## Alert rules

Folder `Alerting`, rule group `infra`, evaluated every 60s.

| Rule | Query | Threshold | Severity |
|---|---|---|---|
| Node down | `up{job="integrations/unix"}` | < 1 for 5m | critical |
| Root disk space low | `node_filesystem_avail_bytes / node_filesystem_size_bytes * 100`, mountpoint `/` | < 10 for 10m | critical |
| High memory usage | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` | < 10 for 10m | warning |
| Caddy config reload failed | `caddy_config_last_reload_successful` (TB only) | < 1 for 5m | critical |

All route to a **Telegram** contact point — the Den Den Mushi bot
([why Telegram](../decisions/2026-07-25-telegram-not-ntfy.md)). Bot token and chat id come
from `secrets.env` via Grafana's `$VAR` provisioning interpolation, never from the
provisioning file. `repeat_interval` is 24h. **The notification policy tree is read-only in
the UI** once provisioned: routing, grouping and timing changes go through
`contact-points.yaml`.

Komodo alerts to Discord separately and the two overlap — some alerts arrive twice, and
nobody has narrowed either side yet.

## Extending

Add a rule: copy a block in `rules.yaml`, drop the `uid` key (Grafana assigns one), change
`title` / `expr` / threshold `params` / `for`. Add a dashboard: drop a JSON file into
`dashboards/`. Either way, commit and redeploy `observability` — it already carries
`--force-recreate` for the bind mounts. Pulling live state back out of the UI needs a
service-account token; the commands are in [commands](../runbooks/commands.md).

Only add a scrape target if the app exposes its **own** `/metrics` worth collecting —
container resource usage is already covered.

## Known gaps, on purpose

- **VM / Loki self-health** — neither is scraped as a Prometheus target, so
  `up{job="victoriametrics"}` does not exist. Fixing it is a `prometheus.scrape` block in
  `going-merry/alloy/config.alloy`, not a Grafana change.
- **Container crash-loop detection** — cadvisor doesn't track restart counts outside
  Kubernetes, and `restart: unless-stopped` self-heals most blips.
- **Log-based alerting** — no deployed app yet has a failure signature worth matching.
- **Backup failures** — Backrest has no Prometheus exporter, so there is nothing to query.
