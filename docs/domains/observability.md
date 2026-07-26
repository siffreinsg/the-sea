# Observability

Grafana + VictoriaMetrics + Loki on **GM**
([why GM](../decisions/2026-07-23-observability-on-going-merry.md)), one **Alloy**
collector per node pushing over the mesh. Reached at `grafana.siffreinsigy.me` through
TB's Caddy.

- **VictoriaMetrics** — metrics, 90d retention (VM flag).
- **Loki** — logs, 30d retention (`loki.yaml`), `auth_enabled: false`.
- **Tempo** — traces, 14d retention (the `block_retention` default). Shorter than logs on
  purpose: traces are bulkier. Monolithic single binary on the local filesystem, same
  shape as Loki. **Config is 3.0-only** — that release removed the top-level `ingester:`
  and `compactor:` blocks in favour of live_store / block_builder / backend_scheduler, and
  a 2.x config fails to parse rather than degrading. Copy from the tag's
  `example/docker-compose/single-binary/`, never from an older tutorial.
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

- `provisioning/datasources/grafana-datasources.yaml` — VictoriaMetrics (default), Loki and
  Tempo. They address each other by **compose service DNS**, not the mesh IP; the stack
  moves as a unit, and service DNS sidesteps the hairpin-NAT problem.
  **Do not give VictoriaMetrics an explicit `uid`.** Grafana generated
  `P4169E866C3094E38` and every rule in `alerting/rules.yaml` references it; pinning a
  different one silently breaks all of them. Loki and Tempo have explicit uids because
  they need to name each other for the trace↔log links, and nothing referenced them.

  **Changing the uid of a datasource that already exists takes Grafana down.** Grafana
  matches by uid, so it reports `Datasource provisioning error: data source not found`,
  the provisioning module fails, and the container exits — not a degraded start, a crash.
  The fix is a `deleteDatasources:` entry for that datasource; deletes run before inserts.
  Loki carries one. Never add VictoriaMetrics to that block.
- `provisioning/dashboards/dashboards.yaml` → `dashboards/nodes.json` (1860, node_exporter),
  `dashboards/containers.json` (14282, cadvisor) and `dashboards/ai-platform.json`
  (hand-written: LiteLLM spend, tokens, latency, rate-limit headroom, plus the TraceQL
  cheatsheet for per-call exploration).
- `provisioning/alerting/rules.yaml` and `contact-points.yaml`.

**Provisioned resources are read-only in the UI.** Edit the file and redeploy. Grafana
matches by UID on startup, so it takes over previously UI-created resources rather than
duplicating them. Dashboards re-poll every 30s; alert rules only re-read on container start.

## Traces

Apps never push to Tempo directly. The [mesh guard](networking.md) DROPs `172.16/12` →
`100.64/10` in raw/PREROUTING, so a bridged container cannot reach GM at all. They send
OTLP to **Alloy on their own node**, which is `network_mode: host` and whose traffic is
therefore the host's — the same "one collector per node" shape as metrics and logs.

`thriller-bark/alloy/config.alloy` binds the OTLP receiver on **`0.0.0.0`:4317/4318**, and
that is the one place a listener is not loopback- or mesh-scoped. It has to be: the senders
sit on two different bridges (`172.17.0.1`, `the-sea-internal` at `172.24.0.1`) and gateway
IPs change when a network is recreated. The perimeter firewall is the gate — TB accepts
80/443/22 inbound and nothing else. Alloy's own UI stays pinned to `127.0.0.1:12345`.

Senders use `host.docker.internal` with `extra_hosts: host-gateway`, never a literal
gateway IP, for the same reason.

This works because containers *can* reach the host — proven by connect, not inferred, and
[corrected on that page](networking.md) where it previously said otherwise.

The Grafana links that make three panes into one are in `grafana-datasources.yaml`:
`tracesToLogsV2` on Tempo, and a `TraceID` derived field on Loki. **The Loki direction is
per-app**, because it needs the app to print a trace id in the log line: Open-WebUI does
(`trace_id": "<32 hex>`), LiteLLM does not. Trace→Logs works for both, since that matches
on time window rather than on the log content.

Alloy drops spans that are never worth storing — healthchecks, static assets, SQLAlchemy
connection setup. Only leaf or self-contained spans are dropped; filtering a span with
children would orphan them.

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
container resource usage is already covered. **LiteLLM is the one app that qualifies**
(`prometheus.scrape "litellm"` on TB): spend, tokens, provider latency and rate-limit
headroom per model and virtual key exist nowhere else. Its `/metrics` is unauthenticated
so Alloy needs no key in a plaintext config, and Caddy 404s the path to keep it off the
public internet — **if that Caddy block ever goes, spend and key aliases go public.**

**Panels on low-volume metrics must be range-scoped, not rate-scoped.** This fleet serves a
handful of LLM requests a day, so `rate(...[$__rate_interval])` is zero almost always and
the panel reads as broken rather than idle. The latency quantiles in `ai-platform.json` use
`increase(...[$__range])` on stat panels for exactly this reason.

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
