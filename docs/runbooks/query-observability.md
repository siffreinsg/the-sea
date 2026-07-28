# Query the observability stack

What is collected and why: [observability](../domains/observability.md).

## Query the datastores

```bash
curl -s 'http://100.64.0.1:8428/api/v1/query?query=up' | jq '.data.result[].metric'
curl -s -G 'http://100.64.0.1:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={node="going-merry"}' --data-urlencode 'limit=3'
curl -s http://127.0.0.1:12345/-/ready && docker logs alloy --since 10m   # on the node itself
```

## Pull live Grafana state back into the repo

Needs a service-account token with the Admin role.

```bash
TOK="<token>"; BASE="https://grafana.siffreinsigy.me"
curl -s -H "Authorization: Bearer $TOK" \
  "$BASE/api/v1/provisioning/alert-rules/export?format=yaml" > provisioning/alerting/rules.yaml
curl -s -H "Authorization: Bearer $TOK" "$BASE/api/dashboards/uid/<uid>" \
  | jq .dashboard > dashboards/<name>.json
```

## Install the volume-size collector (once per node)

Same pattern as the dump timers.

```bash
sudo ln -sf /opt/the-sea/<node>/metrics/the-sea-volume-sizes.service /etc/systemd/system/
sudo ln -sf /opt/the-sea/<node>/metrics/the-sea-volume-sizes.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now the-sea-volume-sizes.timer
sudo systemctl start the-sea-volume-sizes.service   # don't wait an hour for the first one
```
