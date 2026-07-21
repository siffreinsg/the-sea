#!/usr/bin/env bash
# Consistent SQL dump of the Headscale sqlite db. Run by the node's backup timer
# (thriller-bark/backups/run.sh); also runnable standalone. The headscale image
# ships no sqlite3, so the host provides it and reads the db via its named volume.
# .dump is transaction-consistent against the live, container-open db.
set -euo pipefail
out=/var/backups/the-sea/dumps/headscale.sql.gz
mkdir -p "$(dirname "$out")"

db="$(docker volume inspect -f '{{.Mountpoint}}' headscale_headscale-data)/db.sqlite"
sqlite3 "$db" .dump | gzip > "$out.part"
mv "$out.part" "$out"
