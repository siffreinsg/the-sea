#!/usr/bin/env bash
# Logical dump of the Postgres that backs LiteLLM (virtual keys, budgets, spend logs)
# and, from Phase 4, Open-WebUI's pgvector store. Run by the node's backup timer
# (thriller-bark/backups/run.sh); also runnable standalone. Overwrites one file —
# restic keeps the history. Atomic: a failed run keeps the last good file.
#
# This lands in the **critical** plan, not bulk: the rows hold virtual keys and spend
# data, which is secrets material per add-a-service.md §3c.
set -euo pipefail
umask 077   # dumps hold app data in the clear; keep them root-only
out=/var/backups/the-sea/dumps/litellm-postgres.sql.gz
mkdir -p "$(dirname "$out")"

# --clean --if-exists so a restore into a live cluster doesn't need a manual drop first.
# Piped to stdout rather than `docker cp`, so the umask above actually applies.
docker exec postgres sh -c \
  'pg_dumpall --clean --if-exists -U "$POSTGRES_USER"' \
  | gzip > "$out.part"
mv "$out.part" "$out"
