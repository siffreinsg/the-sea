# Backups

Two layers: a logical **dump** of every live database, then **Backrest/restic** shipping
files to two cloud remotes ([the design](../ADR/2026-07-21-backrest-restic-proton-mega.md)).
Nothing reaches a provider unencrypted.

**Every stateful service gets a dump plus a plan entry** — mechanics in
[add-a-service](../runbooks/add-a-service.md) §3c, dump harness in [db-dumps](../runbooks/db-dumps.md).

## Who is in which plan

Backrest's own config is deliberately not in git, so **this table is the only written
record of the assignment** — keep it current.

| Node | Critical (Mega) | Bulk (Proton) |
|---|---|---|
| TB | Authelia config + db, Actual Budget, n8n exports, LiteLLM Postgres dump, `/userdata/caddy` (certs — belt-and-suspenders, beyond the ACME-recoverable scoping), `/userdata/headscale`, `/userdata/komodo-keys` | Komodo Mongo dump, headscale dump, Open-WebUI data, the whole `/userdata/backups` dumps dir, `/userdata/headscale`, `/userdata/komodo-keys` |
| GM | Dawarich (`pg_dump`) | your_spotify (`mongodump`), Grafana data, Cleanuparr + Profilarr config |

Both nodes' **bulk** plans include the dumps directory as a *directory* entry
(`/userdata/backups`), not a file list — so a new `backup.sh` is covered the moment it
runs, with nothing to add per app. Those paths are **container-side** mount points as shown
in Backrest's UI, not the host's `/var/backups/the-sea`.

The **LiteLLM Postgres** is on TB and holds virtual keys and spend logs — secrets
material, hence critical rather than bulk, even though it sits in the same dumps directory
the bulk plan sweeps wholesale. It covers LiteLLM only; databases are
[one per app](../ADR/2026-07-28-one-database-per-app.md), so **Open-WebUI dumps its own**
(`open-webui-postgres.sql.gz`) and that one is bulk — chat history is not secrets material.
Nothing to add in Backrest for it: the bulk plan sweeps the dumps directory wholesale.

Since the Postgres cutover, Open-WebUI's `open-webui-data` volume no longer holds the chat
history — it is uploaded files only, and the database dump is what matters.

`/userdata/headscale` and `/userdata/komodo-keys` are **volume** sources, in both TB plans,
not dumps. Headscale's is not redundant with `headscale/backup.sh`: the dump covers
`db.sqlite`, but **`noise_private.key` — which the
[mesh decision](../ADR/2026-07-18-headscale-mesh.md) calls DR-critical — exists only
inside the volume.** Losing it means re-keying the control plane and every node.

Deliberately **not** backed up: media (re-acquirable), VM metrics and Loki logs
(retention-capped 90d/30d), plexautolanguages' `/config` (Plex episode cache, cheaply
rebuilt), Homepage (all config is in git).

## Operating rules

- **`rclone.conf` is mounted read-write**, not `:ro`, in both Backrest compose files.
  protondrive persists its refreshed OAuth token back into the file; a read-only mount broke
  that silently (`device or resource busy` on the rename) and probably caused an earlier
  Proton 401 cascade on TB. The committed encrypted copy is the reset-to-known-good baseline.
- **TB and GM authenticate to the same Proton account**, so the schedules are staggered an
  hour apart to avoid `429 Too many recent logins`. Keep the offset.
- **Instance-sync (peer/hub) is off.** One independent Backrest per node; nothing crosses
  nodes but encrypted restic traffic.
- **Dump units run as root** and glob `<node>/*/backup.sh` from the repo checkout, so
  anything landing a `backup.sh` in a service dir runs as root nightly. The repo is the
  trust boundary — which is why the git token is read-only.
- **A failing dump must stay visible.** `run.sh` exits non-zero if any single dump fails;
  a unit that is *always* failed cannot signal that it has *started* failing.

## Disaster recovery

Clone the repo, drop in the age key, redeploy. What that does **not** restore, and must be
rebuilt by hand: Backrest's repos and plans, the Komodo Discord alerter, three Komodo
Procedures and one Tag, and **the `the-sea-internal` docker network on TB**
(`docker network create the-sea-internal` — it is `external: true` in every compose that
joins it, so `litellm` and `open-webui` will refuse to start until it exists).

**Deploy order matters.** Backrest mounts `external: true` volumes on both nodes (TB:
headscale, caddy, komodo, authelia, open-webui; GM: observability, cleanuparr, profilarr)
and will not start until those stacks have each been deployed once. Deploy the source
stacks before `backrest-tb`.

Restore-relevant identifiers are in [reference](../REFERENCE.md) — full node names, never
abbreviations.
