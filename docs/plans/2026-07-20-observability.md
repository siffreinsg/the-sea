# Observability Implementation Plan (Plan 3 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Reality check:** most steps run on remote hosts (SSH) or in the Grafana/Komodo web UIs. The human runs those; an agent can write the repo files and verify endpoints.

**Goal:** One Grafana at `https://grafana.siffreinsigy.me` showing host + container metrics and logs from both Docker nodes, stored in VictoriaMetrics and Loki on TB.

**Architecture:** Central stack on TB (VictoriaMetrics + Loki + Grafana). One **Grafana Alloy** per node (host-network container) scrapes host metrics (embedded node_exporter), container metrics (embedded cadvisor), and local endpoints (Headscale, Caddy), tails Docker logs, and pushes everything over the mesh to TB. Ingest endpoints bind TB's **mesh IP `100.64.0.2`** (the private-bind rule: cross-node ingest can't use `127.0.0.1`). Sunny/DDM collectors are deferred to `future.md`.

**Tech Stack:** VictoriaMetrics single-node, Loki 3 (single binary, filesystem storage), Grafana, Grafana Alloy.

## Global Constraints

- Never bind `0.0.0.0`. TB: `127.0.0.1` for Caddy-only services, `100.64.0.2` for mesh-ingest (VM, Loki). GM: `100.64.0.1`.
- Binding `100.64.0.2` requires tailscaled up before the container starts — `restart: unless-stopped` retries until it is; expect a few restarts after a TB reboot, not an error.
- Secrets sops-encrypted (`secrets.env` → `.env` via stack `pre_deploy`); decrypted files gitignored.
- New services follow `docs/runbooks/add-a-service.md`. Sync stays **non-prune**; no `[[server]]` blocks.
- Caddyfile changes on TB: `docker compose up -d --force-recreate`, never `caddy reload`.
- Retention: metrics **90d** (VM flag), logs **30d** (Loki compactor). Metrics/logs data is disposable — **not** added to backups (Grafana's own data volume is, in Task 5).
- Image tags current at plan time — check for newer patch releases before deploying, don't chase majors mid-plan.

---

### Task 1: core stack on TB — VictoriaMetrics + Loki + Grafana

**Files:**
- Create: `thriller-bark/observability/compose.yaml`
- Create: `thriller-bark/observability/loki.yaml`
- Create: `thriller-bark/observability/grafana-datasources.yaml`
- Create: `thriller-bark/observability/secrets.env` (sops)
- Modify: `komodo/resources.toml`
- Modify: `thriller-bark/caddy/Caddyfile`

**Interfaces:**
- Produces: metrics write `http://100.64.0.2:8428/api/v1/write` and logs push `http://100.64.0.2:3100/loki/api/v1/push` (Tasks 3/4 point Alloy at these); Grafana at `https://grafana.siffreinsigy.me` with datasources named `VictoriaMetrics` and `Loki` (Task 5).

- [ ] **Step 1: Create `thriller-bark/observability/compose.yaml`**

```yaml
services:
  victoriametrics:
    image: victoriametrics/victoria-metrics:latest
    container_name: victoriametrics
    restart: unless-stopped
    command:
      - -storageDataPath=/storage
      - -retentionPeriod=90d
    ports:
      - "100.64.0.2:8428:8428"   # mesh ingest — GM's Alloy pushes here
    volumes:
      - vm-data:/storage

  loki:
    image: grafana/loki:3
    container_name: loki
    restart: unless-stopped
    command: -config.file=/etc/loki/loki.yaml
    ports:
      - "100.64.0.2:3100:3100"   # mesh ingest
    volumes:
      - ./loki.yaml:/etc/loki/loki.yaml:ro
      - loki-data:/loki

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    env_file: .env
    environment:
      GF_SERVER_ROOT_URL: https://grafana.siffreinsigy.me
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
    ports:
      - "127.0.0.1:3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana-datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml:ro

volumes:
  vm-data:
  loki-data:
  grafana-data:
```

- [ ] **Step 2: Create `thriller-bark/observability/loki.yaml`** (single binary, filesystem storage, 30-day retention)

```yaml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules

schema_config:
  configs:
    - from: "2026-01-01"
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 720h

compactor:
  working_directory: /loki/compactor
  retention_enabled: true
  delete_request_store: filesystem
```

- [ ] **Step 3: Create `thriller-bark/observability/grafana-datasources.yaml`**

```yaml
apiVersion: 1
datasources:
  - name: VictoriaMetrics
    type: prometheus
    access: proxy
    url: http://100.64.0.2:8428
    isDefault: true
  - name: Loki
    type: loki
    access: proxy
    url: http://100.64.0.2:3100
```

- [ ] **Step 4: Create the secret**

```bash
cd ~/projects/the-sea
echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 24)" > thriller-bark/observability/secrets.env
sops -e -i thriller-bark/observability/secrets.env
```
Store the password in the password manager ("Grafana admin").

- [ ] **Step 5: Append to `komodo/resources.toml`**

```toml
[[stack]]
name = "observability"
[stack.config]
server = "thriller-bark"
git_account = "siffreinsg"
repo = "siffreinsg/the-sea"
branch = "main"
run_directory = "thriller-bark/observability"
pre_deploy.command = "sops -d secrets.env > .env"
```

- [ ] **Step 6: Caddy handle** (above the final `handle { abort }`)

```caddyfile
	@grafana host grafana.siffreinsigy.me
	handle @grafana {
		reverse_proxy 127.0.0.1:3000
	}
```

- [ ] **Step 7: Ship it**

```bash
git add thriller-bark/observability komodo/resources.toml thriller-bark/caddy/Caddyfile
git commit -m "feat(observability): VM + Loki + Grafana on thriller-bark" && git push
```
Komodo UI: Execute the `the-sea` Sync → **Deploy** `observability`. Then on TB:
```bash
cd /opt/the-sea && git pull && cd thriller-bark/caddy && docker compose up -d --force-recreate
```

- [ ] **Step 8: Verify all three, on TB**

```bash
curl -s http://100.64.0.2:8428/health          # VictoriaMetrics: OK
curl -s http://100.64.0.2:3100/ready           # Loki: ready (may take ~15s after start)
curl -s -o /dev/null -w '%{http_code}\n' https://grafana.siffreinsigy.me/login   # 200
```
Log into Grafana (`admin` / password from Step 4) → Connections → Data sources → both provisioned, "Save & test" green. Verify from GM too: `curl -s http://100.64.0.2:8428/health` over the mesh → OK.

---

### Task 2: expose TB scrape endpoints (Headscale metrics + Caddy metrics)

**Files:**
- Modify: `thriller-bark/headscale/config.yaml` (metrics listen addr)
- Modify: `thriller-bark/headscale/compose.yaml` (publish metrics port)
- Modify: `thriller-bark/caddy/Caddyfile` (global `metrics` option)

**Interfaces:**
- Produces: `http://127.0.0.1:9090/metrics` (Headscale) and `http://127.0.0.1:2019/metrics` (Caddy admin) on TB — Task 3's Alloy scrapes both.

- [ ] **Step 1: In `thriller-bark/headscale/config.yaml`**, make metrics reachable from outside the container netns (the publish below still pins it to TB loopback):

```yaml
metrics_listen_addr: 0.0.0.0:9090
```

- [ ] **Step 2: In `thriller-bark/headscale/compose.yaml`**, add to the `headscale` service `ports:`

```yaml
      - "127.0.0.1:9090:9090"    # metrics — scraped by local Alloy only
```

- [ ] **Step 3: In `thriller-bark/caddy/Caddyfile`**, add to the global options block (the `{ ... }` at the top):

```caddyfile
	metrics
```

- [ ] **Step 4: Commit + apply on TB** (manual stacks)

```bash
git add thriller-bark/headscale thriller-bark/caddy/Caddyfile
git commit -m "feat(observability): expose headscale + caddy metrics on TB loopback" && git push
```
On TB:
```bash
cd /opt/the-sea && git pull
cd thriller-bark/headscale && docker compose up -d
cd ../caddy && docker compose up -d --force-recreate
```

- [ ] **Step 5: Verify**

```bash
curl -s http://127.0.0.1:9090/metrics | head -3      # headscale_* / go_* series
curl -s http://127.0.0.1:2019/metrics | head -3      # caddy_* series
curl -s http://127.0.0.1:8080/health                  # headscale still healthy
curl -s -o /dev/null -w '%{http_code}\n' https://up.siffreinsigy.me   # 200 — caddy still fine
```

---

### Task 3: Alloy on TB

**Files:**
- Create: `thriller-bark/alloy/compose.yaml`
- Create: `thriller-bark/alloy/config.alloy`
- Modify: `komodo/resources.toml`

**Interfaces:**
- Consumes: ingest endpoints (T1), scrape endpoints (T2).
- Produces: series labeled `node="thriller-bark"` in VM; log streams labeled `node="thriller-bark"`, `container=<name>` in Loki. Task 4 copies this config with the GM diffs; Task 5's dashboards filter on the `node` label.

- [ ] **Step 1: Create `thriller-bark/alloy/config.alloy`**

```alloy
// ---- outputs ----
prometheus.remote_write "vm" {
  endpoint {
    url = "http://100.64.0.2:8428/api/v1/write"
  }
}

loki.write "central" {
  endpoint {
    url = "http://100.64.0.2:3100/loki/api/v1/push"
  }
  external_labels = { node = "thriller-bark" }
}

// every metric gets node="thriller-bark" before leaving
prometheus.relabel "add_node" {
  forward_to = [prometheus.remote_write.vm.receiver]
  rule {
    target_label = "node"
    replacement  = "thriller-bark"
  }
}

// ---- host metrics (embedded node_exporter) ----
prometheus.exporter.unix "host" {
  procfs_path = "/host/proc"
  sysfs_path  = "/host/sys"
  rootfs_path = "/host/root"
}
prometheus.scrape "host" {
  targets    = prometheus.exporter.unix.host.targets
  forward_to = [prometheus.relabel.add_node.receiver]
}

// ---- container metrics (embedded cadvisor) ----
prometheus.exporter.cadvisor "containers" {
  docker_host = "unix:///var/run/docker.sock"
}
prometheus.scrape "containers" {
  targets    = prometheus.exporter.cadvisor.containers.targets
  forward_to = [prometheus.relabel.add_node.receiver]
}

// ---- local endpoints ----
prometheus.scrape "headscale" {
  targets    = [{ __address__ = "127.0.0.1:9090", job = "headscale" }]
  forward_to = [prometheus.relabel.add_node.receiver]
}
prometheus.scrape "caddy" {
  targets    = [{ __address__ = "127.0.0.1:2019", job = "caddy" }]
  forward_to = [prometheus.relabel.add_node.receiver]
}

// ---- docker logs ----
discovery.docker "local" {
  host = "unix:///var/run/docker.sock"
}
discovery.relabel "logs" {
  targets = discovery.docker.local.targets
  rule {
    source_labels = ["__meta_docker_container_name"]
    regex         = "/(.*)"
    target_label  = "container"
  }
}
loki.source.docker "logs" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.relabel.logs.output
  forward_to = [loki.write.central.receiver]
}
```

- [ ] **Step 2: Create `thriller-bark/alloy/compose.yaml`**

```yaml
services:
  alloy:
    image: grafana/alloy:latest
    container_name: alloy
    network_mode: host   # scrapes 127.0.0.1 targets; UI pinned to loopback below
    restart: unless-stopped
    command:
      - run
      - /etc/alloy/config.alloy
      - --storage.path=/var/lib/alloy/data
      - --server.http.listen-addr=127.0.0.1:12345
    volumes:
      - ./config.alloy:/etc/alloy/config.alloy:ro
      - alloy-data:/var/lib/alloy/data
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/host/root:ro,rslave

volumes:
  alloy-data:
```

- [ ] **Step 3: Append to `komodo/resources.toml`** (no secrets → no pre_deploy)

```toml
[[stack]]
name = "alloy-tb"
[stack.config]
server = "thriller-bark"
git_account = "siffreinsg"
repo = "siffreinsg/the-sea"
branch = "main"
run_directory = "thriller-bark/alloy"
```

- [ ] **Step 4: Ship it** — commit `thriller-bark/alloy komodo/resources.toml` (`feat(alloy): collector on thriller-bark`), push, Komodo Sync → Deploy `alloy-tb`.

- [ ] **Step 5: Verify components are healthy** — on TB:

```bash
docker logs alloy 2>&1 | grep -iE 'error|failed' | head    # expect nothing fatal
curl -s http://127.0.0.1:12345/-/ready                      # Alloy ready
```
If `prometheus.exporter.cadvisor` alone errors on this OpenVZ-adjacent-free ARM host, it's the nice-to-have: remove that component pair from `config.alloy` and redeploy rather than fighting it.

- [ ] **Step 6: Verify data lands** — series in VM and logs in Loki:

```bash
curl -s 'http://100.64.0.2:8428/api/v1/query?query=up{node="thriller-bark"}' | head -c 400
curl -s 'http://100.64.0.2:8428/api/v1/query?query=node_uname_info' | head -c 400
curl -s -G 'http://100.64.0.2:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={node="thriller-bark"}' --data-urlencode 'limit=3' | head -c 400
```
Expected: non-empty `result` arrays in all three.

---

### Task 4: Alloy on GM

**Files:**
- Create: `going-merry/alloy/compose.yaml`
- Create: `going-merry/alloy/config.alloy`
- Modify: `komodo/resources.toml`

**Interfaces:**
- Produces: `node="going-merry"` metrics + logs in VM/Loki.

- [ ] **Step 1: Create `going-merry/alloy/config.alloy`** — identical to `thriller-bark/alloy/config.alloy` (T3 Step 1) with exactly these diffs: every `"thriller-bark"` → `"going-merry"`, and **delete** the two local-endpoint scrapes (`prometheus.scrape "headscale"` and `prometheus.scrape "caddy"` — those services live on TB).

- [ ] **Step 2: Create `going-merry/alloy/compose.yaml`** — same as T3 Step 2 (host network is required to dial `100.64.0.2` over GM's kernel-mode tailscale; the UI stays on `127.0.0.1:12345`, which never touches GM's public interface).

- [ ] **Step 3: Append to `komodo/resources.toml`**

```toml
[[stack]]
name = "alloy-gm"
[stack.config]
server = "going-merry"
git_account = "siffreinsg"
repo = "siffreinsg/the-sea"
branch = "main"
run_directory = "going-merry/alloy"
```

- [ ] **Step 4: Ship it** — commit `going-merry/alloy komodo/resources.toml` (`feat(alloy): collector on going-merry`), push, Komodo Sync → Deploy `alloy-gm`.

- [ ] **Step 5: Verify** — on GM: `docker logs alloy 2>&1 | grep -iE 'error|failed' | head` (nothing fatal; same cadvisor escape hatch as T3 — likelier here given the OpenVZ 4.19 kernel). Then from TB or GM:

```bash
curl -s 'http://100.64.0.2:8428/api/v1/query?query=up{node="going-merry"}' | head -c 400
curl -s -G 'http://100.64.0.2:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={node="going-merry", container="whoami"}' --data-urlencode 'limit=3' | head -c 400
```
Expected: non-empty results — whoami logs prove GM container logs flow end-to-end.

---

### Task 5: dashboards, backup tie-in, docs

**Files:**
- Modify: `docs/runbooks/commands.md`
- Modify: `docs/specs/future.md`
- Modify: `docs/HANDOFF.md` (local, not committed)

- [ ] **Step 1: Import dashboards** in Grafana (Dashboards → New → Import, datasource = VictoriaMetrics):
  - **1860** — Node Exporter Full: pick each node via the instance/node variable; CPU/mem/disk/net graphs populate for both.
  - **14282** — cadvisor exporter: per-container CPU/mem (skip if cadvisor was dropped in T3/T4).
  - Explore → Loki → `{container="whoami"}` — logs stream. No custom dashboards tonight; build them when a real question needs one.

- [ ] **Step 2: Back up Grafana's state** — Backrest TB UI: add external volume mount first. In `thriller-bark/backrest/compose.yaml` add under the backup-sources mounts and external volumes (mirroring the existing entries):

```yaml
      - grafana-data:/userdata/grafana:ro
```
```yaml
  grafana-data:
    external: true
    name: observability_grafana-data
```
Commit (`feat(backrest): include grafana data`), push, Komodo Sync → redeploy `backrest-tb`, then add `/userdata/grafana` to the `tb-bulk` plan paths in the Backrest UI. VM/Loki data stays out — disposable.

- [ ] **Step 3: Append to `docs/runbooks/commands.md`** — a new `## Observability (Thriller Bark)` section containing: a bash block with the data-flow checks (`curl -s 'http://100.64.0.2:8428/api/v1/query?query=up' | jq '.data.result[].metric'` and the Loki `query_range` with `{node="going-merry"}`), a collector-health check (`curl -s http://127.0.0.1:12345/-/ready && docker logs alloy --since 10m`), and two prose lines: Grafana URL + "admin pw in password manager", and "Retention: metrics 90d (VM flag), logs 30d (loki.yaml). Neither is backed up; grafana-data is."

- [ ] **Step 4: Append to `docs/specs/future.md`** under Deferred decisions:

```markdown
- **Sunny / Den Den Mushi collectors** — userspace Alloy binary on Sunny, HAOS Prometheus
  add-on or mesh scrape for DDM; both push to VM/Loki on TB (100.64.0.2).
- **Alerting** — Grafana alert rules (disk full, backup plan failed, node down) once
  baseline dashboards have run for a while.
```

- [ ] **Step 5: Update `docs/HANDOFF.md`** — Plan 3 done; next is the GM app migration backlog; note the ingest endpoints (`100.64.0.2:8428` / `:3100`) and the "new node → copy an alloy dir, change the node label" pattern. Do not commit.

- [ ] **Step 6: Commit the docs**

```bash
git add docs/runbooks/commands.md docs/specs/future.md thriller-bark/backrest
git commit -m "docs(observability): commands + deferred items (closes Plan 3)" && git push
```
