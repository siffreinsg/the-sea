#!/usr/bin/env bash
# Consistent SQLite dump of Karakeep's DB. Run by going-merry/backups/run.sh;
# also runnable standalone. Overwrites one file — Backrest keeps the history.
# Never `cp` a live SQLite file; sqlite3 .backup is the online-safe path.
set -euo pipefail
umask 077
out=/var/backups/the-sea/dumps/karakeep.sqlite3

docker exec karakeep sh -c \
  "sqlite3 \$DATA_DIR/db.db '.backup /tmp/karakeep-backup.db'"
docker cp karakeep:/tmp/karakeep-backup.db "$out.part"
docker exec karakeep rm /tmp/karakeep-backup.db
chmod 600 "$out.part"
mv "$out.part" "$out"
