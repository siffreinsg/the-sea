#!/usr/bin/env bash
# Runs every TB service's backup.sh. Adding a stateful service = drop a backup.sh
# in its dir; it's picked up here automatically, no edits. One failing dump is
# reported but doesn't stop the others; overall exit is non-zero if any failed.
shopt -s nullglob
rc=0
for f in /opt/the-sea/thriller-bark/*/backup.sh; do
  echo "== $f"
  "$f" || rc=1
done
exit $rc
