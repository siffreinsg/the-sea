#!/usr/bin/env bash
# Consistent snapshot of Actual's data dir (account.sqlite + budget file blobs).
# Run by the node's backup timer (thriller-bark/backups/run.sh); also runnable
# standalone. Overwrites one archive — restic (Backrest critical plan) keeps
# the history. Atomic: a failed run keeps the last good file.
set -euo pipefail
out=/var/backups/the-sea/dumps/actualbudget-data.tar.gz
mkdir -p "$(dirname "$out")"

docker exec actual_server tar -C /data -czf - . > "$out.part"
mv "$out.part" "$out"
# ponytail: raw tar, not a sqlite3 .backup snapshot — Actual writes are
# infrequent (sync on save, not a hot connection pool). Switch to `sqlite3
# account.sqlite ".backup ..."` first if corruption ever shows up in a restore.
