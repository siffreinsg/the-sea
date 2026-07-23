# Plan — migrate observability stack (Grafana + VictoriaMetrics + Loki) TB → GM

**Why:** GM's disk is ~17× TB's (95k/41k vs 5.5k/2.4k IOPS) and VM/Loki are write-heavy
time-series; TB's throttled Oracle volume is the fleet's scarce resource. See
`docs/specs/node-performance.md`. Delete this doc once done.

**Scope:** relocate the live stack, don't rebuild it. Grafana settings/dashboards are
preserved; VM/Loki *history* is dropped (re-generates, not worth migrating).

**Guardrail:** don't tear down the TB stack until GM is verified — rollback = revert
the alloy/Caddy target flips and redeploy TB observability from git.

## Tasks

1. **Relocate in repo** — move `thriller-bark/observability/` → `going-merry/observability/`
   (`compose.yaml`, `grafana-datasources.yaml`, `loki.yaml`, `secrets.env`).
   - Bind services to **`100.64.0.1`** (were `127.0.0.1` on TB).
   - Keep datasources on compose-service DNS (`victoriametrics`/`loki`) — the stack
     moves together, so no hairpin-NAT rewrite needed. `grafana-datasources.yaml`
     unchanged.
   - Keep `extra_args = ["--force-recreate"]` (git-tracked single-file bind mounts).
   - **Add retention caps** now: VM `-retentionPeriod`, Loki `limits_config`
     retention — bound disk churn regardless of node.

2. **Komodo sync** — in `komodo/resources.toml`, repoint the `observability` stack
   from the TB server to the GM server (path `going-merry/observability`). Keep the
   Sync **non-prune**.

3. **Flip Alloy targets** — in **both** `thriller-bark/alloy/config.alloy` and
   `going-merry/alloy/config.alloy`, change `100.64.0.2` → `100.64.0.1` (VM `:8428`,
   Loki `:3100`). Both alloy stacks already carry `--force-recreate`.

4. **Caddy** — repoint the `grafana` route's `reverse_proxy` to `100.64.0.1:<grafana
   port>` (was TB-local). After pulling: `cd .../caddy && docker compose up -d
   --force-recreate` (Caddyfile inode pin).

5. **Grafana state — skip migration, start fresh.** User doesn't mind re-clicking:
   let the GM `grafana-data` volume start empty, re-import dashboards 1860 and 14282
   after first boot. Datasources are provisioned from `grafana-datasources.yaml`
   (git-tracked), so those come back automatically.

6. **Backups** — add `grafana-data` to **GM's** bulk Backrest plan; remove it from
   TB's bulk plan.

7. **Verify** (before decommissioning TB):
   - Grafana loads via Caddy; both datasources green.
   - Both nodes' host/container metrics land in VM; logs land in Loki.
   - **Watch the same-host hairpin path:** GM's Alloy → GM's VM/Loki on `100.64.0.1`
     is a same-host mesh-IP hop — the exact pattern that broke Grafana's datasources
     on TB. Confirm GM-origin metrics/logs actually arrive; if not, point GM's Alloy
     at a localhost-published VM/Loki port instead.

8. **Decommission + docs** — remove `thriller-bark/observability/` (repo + TB, confirm
   stack down). Update `foundation-design.md` service-distribution table and HANDOFF
   operating rules (obs on GM). `node-performance.md` already reflects it.
