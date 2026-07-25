#!/usr/bin/env bash
# Consistent logical dump of the your_spotify Mongo db. Run by the node's backup
# timer (going-merry/backups/run.sh); also runnable standalone. Overwrites one
# file — restic (Backrest bulk plan) keeps the history. Atomic: a failed run
# keeps the last good file.
set -euo pipefail
out=/var/backups/the-sea/dumps/your_spotify-mongo.archive.gz
mkdir -p "$(dirname "$out")"

# no auth on this mongo — it's only reachable on the compose network.
docker exec your_spotify_mongo sh -c \
  'mongodump --db your_spotify --archive --gzip' \
  > "$out.part"
mv "$out.part" "$out"
