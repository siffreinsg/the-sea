#!/usr/bin/env bash
# Consistent logical dump of the Komodo Mongo db. Run by the node's backup timer
# (thriller-bark/backups/run.sh); also runnable standalone. Overwrites one file —
# restic (Backrest bulk plan) keeps the history. Atomic: a failed run keeps the
# last good file.
set -euo pipefail
out=/var/backups/the-sea/dumps/komodo-mongo.archive.gz
mkdir -p "$(dirname "$out")"

# password is expanded inside the container (single quotes), not on the host.
docker exec komodo-mongo sh -c \
  'mongodump -u komodo -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --archive --gzip' \
  > "$out.part"
mv "$out.part" "$out"
