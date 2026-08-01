# Observability

Grafana + VictoriaMetrics + Loki on **GM**
([why GM](../ADR/2026-07-23-observability-on-going-merry.md)), one **Alloy**
collector per node pushing over the mesh. Reached at `grafana.siffreinsigy.me` through
TB's Caddy.

- **VictoriaMetrics** — metrics, 90d retention (VM flag).
- **Loki** — logs, 30d retention (`loki.yaml`), `auth_enabled: false`.
- **Tempo** — traces, 14d retention (the `block_retention` default). Shorter than logs on
  purpose: traces are bulkier. Monolithic single binary on the local filesystem, same
  shape as Loki. **`tempo.yaml` is 3.0-only and a 2.x example will not parse** — the trap
  and the reference config are in the file's own header.
- **Alloy** — scrapes container and host metrics, tails logs. Discovers **all** containers
  via docker.sock with no allowlist, so a new service is collected automatically:
  logs land as `{container="<app>"}`, container metrics via cadvisor, both labelled
  `node=<node>`.

None of VM, Loki or Tempo is backed up (retention-capped by design); `grafana-data` is.
None has authentication — they bind the mesh and rely on it being trusted, which is why
[containers must not reach the tailnet](networking.md).
Alloy's privilege is the fleet's widest; the honest blast radius is in [secrets](secrets.md).

## Provisioned as code

Datasources, dashboards and alert rules are all provisioned from files bind-mounted into
the Grafana container:

- `grafana-datasources.yaml` (→ `provisioning/datasources/`) — VictoriaMetrics (default),
  Loki and Tempo. They address each other by **compose service DNS**, not the mesh IP; the
  stack moves as a unit, and service DNS sidesteps the hairpin-NAT problem.
  **Never give VictoriaMetrics an explicit `uid`, and never add it to `deleteDatasources:`**
  — every alert rule references its generated uid. Changing the uid of an existing
  datasource crashes Grafana on start rather than degrading; the mechanics are in the
  file's header.
- `provisioning/dashboards/dashboards.yaml` → `dashboards/nodes.json` (1860, node_exporter),
  `dashboards/containers.json` (14282, cadvisor), `dashboards/ai-platform.json`
  (hand-written: LiteLLM spend, tokens, latency, rate-limit headroom, plus the TraceQL
  cheatsheet for per-call exploration), `dashboards/resources-<node>.json`
  (hand-written: which container or volume is eating RAM, CPU and disk),
  `dashboards/infra-services.json` (hand-written: Caddy request rate/latency/errors,
  headscale node count and map-response rate, SearXNG engine reliability — the three
  scraped jobs that had metrics in VictoriaMetrics but no panel) and
  `dashboards/service-logs.json` (hand-written: one Loki logs panel behind a `container`
  template variable, covers every current and future container without a dashboard per
  app).
  **One resources dashboard per node, not one with a node filter.** Container names are
  long enough that a `node — name` legend truncates in a bargauge to the point of being
  unreadable, and you look at these one box at a time anyway. TB's copy omits the
  writable-layer panel: cadvisor does not report `container_fs_usage_bytes` there.
- `provisioning/alerting/rules.yaml` and `contact-points.yaml`.

**Provisioned resources are read-only in the UI.** Edit the file and redeploy. Grafana
matches by UID on startup, so it takes over previously UI-created resources rather than
duplicating them. Dashboards re-poll every 30s; alert rules only re-read on container start.

## Traces

Apps never push to Tempo directly. The [mesh guard](networking.md) DROPs bridged-container
traffic to the mesh, so they send OTLP to **Alloy on their own node** instead, which is
`network_mode: host` and whose traffic is therefore the host's — the same "one collector
per node" shape as metrics and logs.

`thriller-bark/alloy/config.alloy` binds `0.0.0.0:4317/4318` — senders are bridged
containers on different bridges, and `host.docker.internal` resolves to one address
regardless of which bridge a container is on, so there's no single non-catch-all bind
every sender's gateway can reach. The mesh guard and perimeter firewall are the
compensating control, same reasoning as `gm-relay`'s loopback proxies. Alloy's own UI
stays `127.0.0.1:12345`.

Senders use `host.docker.internal` with `extra_hosts: host-gateway`, never a literal
gateway IP. This works because [containers can reach the host](networking.md).

The Grafana links that make three panes into one are in `grafana-datasources.yaml`:
`tracesToLogsV2` on Tempo, and a `TraceID` derived field on Loki. **The Loki direction is
per-app**, because it needs the app to print a trace id in the log line: Open-WebUI does
(`trace_id": "<32 hex>`), LiteLLM does not. Trace→Logs works for both, since that matches
on time window rather than on the log content.

Alloy drops spans that are never worth storing — healthchecks, static assets, SQLAlchemy
connection setup. Only leaf or self-contained spans are dropped; filtering a span with
children would orphan them.

## Docker volume sizes

**cadvisor cannot see where the disk went.** It measures a container's writable layer;
every byte that matters — Postgres, Loki, VictoriaMetrics, Tempo, chat history — sits in a
named volume it does not measure, so a dashboard built on cadvisor alone names the wrong
culprit for a full disk.

`<node>/metrics/volume-sizes.sh` runs hourly, `du`s each volume and writes
`docker_volume_size_bytes` into the node_exporter textfile directory, which Alloy's
embedded unix exporter reads on every scrape (`enable_collectors = ["textfile"]`). Hourly
because `du` over every volume is the expensive part, and disk pressure builds over days.

Install it per node with the [query-observability runbook](../runbooks/query-observability.md).

## Alert rules

Folder `Alerting`, rule group `infra`, evaluated every 60s.

| Rule | Query | Threshold | Severity |
| --- | --- | --- | --- |
| Node down | `up{job="integrations/unix"}` | < 1 for 5m | critical |
| Root disk space low | `node_filesystem_avail_bytes / node_filesystem_size_bytes * 100`, mountpoint `/` | < 10 for 10m | critical |
| High memory usage | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` | < 10 for 10m | warning |
| Caddy config reload failed | `caddy_config_last_reload_successful` (TB only) | < 1 for 5m | critical |
| Headscale down | `up{job="headscale"}` (TB only) | < 1 for 5m | critical |
| LLM spend above threshold | `sum(increase(litellm_spend_metric_total[24h]))` | > EUR 2/day for 15m | warning |
| LLM provider errors | `sum(rate(litellm_proxy_failed_requests_metric_total[15m]))` | sustained > 0 for 10m | warning |

The two LLM rules — **and only those two** — use `noDataState: OK`: neither series exists
before the first request or the first failure, and an idle gateway is not an incident.
Everything else, Caddy included, uses `noDataState: Alerting`, where a missing series means
the watched thing is gone. The spend threshold sits far above current usage (fractions of a
cent/day): it catches a runaway loop or a leaked key, not normal chatting.

All route to a **Telegram** contact point — the Den Den Mushi bot
([why Telegram](../ADR/2026-07-25-telegram-not-ntfy.md)). Bot token and chat id come
from `secrets.env` via Grafana's `$VAR` provisioning interpolation, never from the
provisioning file. `repeat_interval` is 24h. **The notification policy tree is read-only in
the UI** once provisioned: routing and timing changes go through `contact-points.yaml`.

Komodo alerts to Discord separately and the two overlap: some alerts arrive twice
([narrowing them](../FUTURE.md)).

## Extending

Add a rule: copy a block in `rules.yaml`, drop the `uid` key (Grafana assigns one), change
`title` / `expr` / threshold `params` / `for`. Add a dashboard: drop a JSON file into
`dashboards/`. Either way, commit and redeploy `observability` — it already carries
`--force-recreate` for the bind mounts. Pulling live state back out of the UI needs a
service-account token; the commands are in [query-observability](../runbooks/query-observability.md).

Only add a scrape target if the app exposes its **own** `/metrics` worth collecting —
container resource usage is already covered. **LiteLLM is the one app that qualifies**
(`prometheus.scrape "litellm"` on TB): spend, tokens, provider latency and rate-limit
headroom per model and virtual key exist nowhere else. Its `/metrics` is unauthenticated,
and Caddy 404s the path — **if that Caddy block ever goes, spend and key aliases go public.**

**Panels on low-volume metrics must be range-scoped, not rate-scoped.** A handful of LLM
requests a day makes `rate(...[$__rate_interval])` zero almost always, so the panel reads as
broken rather than idle. `ai-platform.json`'s latency quantiles use `increase(...[$__range])`.

## Known gaps, on purpose

- **No app emits traces yet.** Tempo and the ingest path exist; wiring LiteLLM,
  Open-WebUI and n8n's own spans is Phase 3 of the AI platform plan. n8n is the only one
  configured so far.
- **VM / Loki / Tempo self-health** — none is scraped as a Prometheus target, so
  `up{job="victoriametrics"}` does not exist. Fixing it is a `prometheus.scrape` block in
  `going-merry/alloy/config.alloy`, not a Grafana change.
- **Container crash-loop detection** — cadvisor doesn't track restart counts outside
  Kubernetes, and `restart: unless-stopped` self-heals most blips.
- **Log-based alerting** — no deployed app yet has a failure signature worth matching.
- **Backup failures** — Backrest has no Prometheus exporter, so there is nothing to query.
