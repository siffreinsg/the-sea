# Grafana dashboards & alerting

State as of 2026-07-23. Grafana runs on GM (`going-merry/observability/`),
`https://grafana.siffreinsigy.me`. Datasources: VictoriaMetrics (`P4169E866C3094E38`,
default) and Loki (`P8E80F9AEF21F6940`), both provisioned via
`grafana-datasources.yaml`.

Dashboards and alert rules are **provisioned as code** — same mechanism as
datasources. Files:
- `provisioning/dashboards/dashboards.yaml` — file provider pointing at `dashboards/`.
- `dashboards/nodes.json`, `dashboards/containers.json` — exported dashboard 1860/14282.
- `provisioning/alerting/rules.yaml` — the 4 alert rules below, exported via
  Grafana's native `alert-rules/export` endpoint.

All three are bind-mounted into the `grafana` container in `compose.yaml`.
Provisioned resources are **read-only in the UI** — edit the file and
redeploy, don't click-edit. Grafana matches by UID on startup, so it takes
over the previously UI/API-created dashboards and rules rather than
duplicating them; dashboards also poll every 30s (`updateIntervalSeconds`),
alert rules only re-read on container start/reload.

## What's live

**Dashboards** (General folder):
- **1860** "Nodes" — node_exporter host metrics, both nodes.
- **14282** "Containers" — cadvisor container metrics, both nodes.

**Alert rules** (folder `Alerting`, rule group `infra`, evaluated every 60s):

| Rule | Query | Threshold | Severity |
|---|---|---|---|
| Node down | `up{job="integrations/unix"}` | < 1 for 5m | critical |
| Root disk space low | `node_filesystem_avail_bytes / node_filesystem_size_bytes * 100` (mountpoint `/`) | < 10 for 10m | critical |
| High memory usage | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` | < 10 for 10m | warning |
| Caddy config reload failed | `caddy_config_last_reload_successful` (TB only) | < 1 for 5m | critical |

All route to Grafana's built-in default contact point.

## The gap: no notification channel

**Nothing currently pages anyone.** Rules fire and show up in the Alerting UI
only. The intended channel is a Telegram bot (see `docs/specs/future.md`) —
deliberately **not ntfy**, that was already decided against. Grafana can talk
to Telegram natively (bot token + chat id), no n8n required — ask to wire
that up when ready; it's a contact-point + notification-policy change, no
rule edits needed.

## Extend

Add a rule: copy a block in `provisioning/alerting/rules.yaml`, drop the
`uid` key (Grafana assigns one), change `title`/`expr`/threshold `params`/`for`.
Add a dashboard: drop a dashboard JSON into `dashboards/`, or export one from
the UI (Dashboard settings → JSON Model) and save it there.

Either way: commit, push, redeploy the `observability` stack (Komodo, same as
any config change here — it already carries `--force-recreate` for the
bind-mounted files).

To pull the *current live* state back out (e.g. after a UI tweak you want to
keep), a service account token (Administration → Service accounts → Admin
role → Add token) gets you:

```bash
TOK="<service-account-token>"
BASE="https://grafana.siffreinsigy.me"

curl -s -H "Authorization: Bearer $TOK" \
  "$BASE/api/v1/provisioning/alert-rules/export?format=yaml" > provisioning/alerting/rules.yaml

curl -s -H "Authorization: Bearer $TOK" "$BASE/api/dashboards/uid/<uid>" \
  | jq .dashboard > dashboards/<name>.json
```

## Known gaps (not fixed, on purpose)

- **VictoriaMetrics / Loki self-health** — not alertable; neither is scraped
  as a Prometheus target (`up{job="victoriametrics"}` doesn't exist). Needs a
  `prometheus.scrape` block added to `going-merry/alloy/config.alloy`, not a
  Grafana-side change.
- **Container crash-loop detection** — skipped. cadvisor doesn't track
  restart counts without Kubernetes; `restart: unless-stopped` self-heals
  most transient blips. Dashboard 14282 covers ad hoc inspection.
- **Log-based (Loki) alerting** — skipped. No deployed app yet has a known
  failure signature worth matching; revisit once Dawarich/Authelia etc. are
  live and a real log pattern is worth alerting on.
- **Backup failures (Backrest)** — no Prometheus exporter exists for
  Backrest, nothing to query.
