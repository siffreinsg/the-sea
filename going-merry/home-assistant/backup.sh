#!/usr/bin/env bash
# Consistent SQL dump of HA's recorder sqlite db. Run by the node's backup timer
# (going-merry/backups/run.sh); also runnable standalone. The HA image ships no
# sqlite3, so the host provides it and reads the db via its named volume.
# .dump is transaction-consistent against the live, container-open db.
set -euo pipefail
umask 077   # dumps hold app data in the clear; keep them root-only
out=/var/backups/the-sea/dumps/home-assistant.sql.gz
mkdir -p "$(dirname "$out")"

db="$(docker volume inspect -f '{{.Mountpoint}}' home-assistant_config)/home-assistant_v2.db"
sqlite3 "$db" .dump | gzip > "$out.part"
mv "$out.part" "$out"
