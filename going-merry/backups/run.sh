#!/usr/bin/env bash
# Runs every GM service's backup.sh. Adding a stateful service = drop a backup.sh
# in its dir; it's picked up here automatically, no edits. One failing dump is
# reported but doesn't stop the others; overall exit is non-zero if any failed.
# Dumps hold plaintext app data (Dawarich's full GPS history), so everything created
# below is 0600 and the directory itself is 0700 — a backup.sh that forgets stays safe.
umask 077
shopt -s nullglob
rc=0
for f in /opt/the-sea/going-merry/*/backup.sh; do
  echo "== $f"
  "$f" || rc=1
done
exit $rc
