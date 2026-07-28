#!/usr/bin/env bash
# Logical dump of Open-WebUI's own Postgres: chat history, users, and the pgvector
# document store. Run by the node's backup timer (thriller-bark/backups/run.sh); also
# runnable standalone. Overwrites one file — restic keeps the history. Atomic: a failed
# run keeps the last good file.
#
# Bulk, not critical: chat history is not secrets material, unlike LiteLLM's virtual keys.
# It needs no Backrest plan entry — TB's bulk plan sweeps /userdata/backups as a directory.
#
# The vectors are dumped with everything else and are the expensive part to lose: a
# re-embed of the whole corpus is billed per token at Scaleway.
set -euo pipefail
umask 077   # dumps hold app data in the clear; keep them root-only
out=/var/backups/the-sea/dumps/open-webui-postgres.sql.gz
mkdir -p "$(dirname "$out")"

# --clean --if-exists so a restore into a live cluster doesn't need a manual drop first.
# Piped to stdout rather than `docker cp`, so the umask above actually applies.
docker exec open-webui-db sh -c \
  'pg_dumpall --clean --if-exists -U "$POSTGRES_USER"' \
  | gzip > "$out.part"
mv "$out.part" "$out"
