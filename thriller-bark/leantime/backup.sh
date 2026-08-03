#!/usr/bin/env bash
# Consistent logical dump of Leantime's MariaDB. Run by the node's backup timer
# (thriller-bark/backups/run.sh); also runnable standalone. Overwrites one file —
# restic (Backrest bulk plan) keeps the history. Atomic: a failed run keeps the
# last good file.
set -euo pipefail
umask 077   # dumps hold app data in the clear; keep them root-only
out=/var/backups/the-sea/dumps/leantime-mariadb.sql.gz
mkdir -p "$(dirname "$out")"

# password is expanded inside the container (single quotes), not on the host.
docker exec leantime_db sh -c \
  'mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases' \
  | gzip > "$out.part"
mv "$out.part" "$out"
