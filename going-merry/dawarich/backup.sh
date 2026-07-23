#!/usr/bin/env bash
# Consistent logical dump of Dawarich's postgis db. Run by the node's backup
# timer (going-merry/backups/run.sh); also runnable standalone. Overwrites one
# file — restic (Backrest bulk + critical plans) keeps the history. Atomic: a
# failed run keeps the last good file.
set -euo pipefail
out=/var/backups/the-sea/dumps/dawarich-postgis.sql.gz
mkdir -p "$(dirname "$out")"

docker exec dawarich_db sh -c \
  'pg_dump -U postgres -d dawarich_development' \
  | gzip > "$out.part"
mv "$out.part" "$out"
