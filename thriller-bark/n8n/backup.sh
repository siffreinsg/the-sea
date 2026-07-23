#!/usr/bin/env bash
# Logical export of n8n workflows + credentials via n8n's own CLI (safer than a
# raw copy of the live SQLite pool). Run by the node's backup timer
# (thriller-bark/backups/run.sh); also runnable standalone. Overwrites two
# files — restic (Backrest critical plan) keeps the history. Atomic: a failed
# run keeps the last good files.
set -euo pipefail
outdir=/var/backups/the-sea/dumps
mkdir -p "$outdir"

docker exec n8n n8n export:workflow --all --output=/tmp/n8n-workflows.json
# decrypted=true: the encryption key lives in data/config, which this export
# doesn't carry — an encrypted-only export would be unrestorable without it.
# Plaintext sits briefly in dumps/ between runs; restic encrypts at rest, and
# this file only ever leaves the critical (encrypted) plan.
docker exec n8n n8n export:credentials --all --output=/tmp/n8n-credentials.json --decrypted=true
docker cp n8n:/tmp/n8n-workflows.json "$outdir/n8n-workflows.json.part"
docker cp n8n:/tmp/n8n-credentials.json "$outdir/n8n-credentials.json.part"
docker exec n8n rm -f /tmp/n8n-workflows.json /tmp/n8n-credentials.json

mv "$outdir/n8n-workflows.json.part" "$outdir/n8n-workflows.json"
mv "$outdir/n8n-credentials.json.part" "$outdir/n8n-credentials.json"
