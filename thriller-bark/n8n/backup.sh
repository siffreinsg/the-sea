#!/usr/bin/env bash
# Logical export of n8n workflows + credentials via n8n's own CLI (safer than a
# raw copy of the live SQLite pool). Run by the node's backup timer
# (thriller-bark/backups/run.sh); also runnable standalone. Overwrites two
# files — restic (Backrest critical plan) keeps the history. Atomic: a failed
# run keeps the last good files.
set -euo pipefail
umask 077   # dumps hold app data in the clear; keep them root-only
outdir=/var/backups/the-sea/dumps
mkdir -p "$outdir"

# n8n's CLI exits non-zero when there is simply nothing to export. That is not
# a backup failure, and letting it propagate leaves the nightly unit
# permanently `failed` — which is how a real failure goes unnoticed. Empty
# export -> empty file, anything else -> propagate.
export_or_empty() { # $1 = /tmp file, rest = n8n export command
  local f=$1 out; shift
  out=$(docker exec n8n "$@" --output="$f" 2>&1) && return 0
  grep -qiE 'no (workflows|credentials) found' <<<"$out" || { printf '%s\n' "$out" >&2; return 1; }
  docker exec n8n sh -c "printf '[]' > $f"
}

export_or_empty /tmp/n8n-workflows.json n8n export:workflow --all
# --decrypted is a bare boolean flag; `--decrypted=true` makes the CLI print its
# usage and exit 1. The encryption key lives in data/config, which this export
# doesn't carry — an encrypted-only export would be unrestorable without it.
# Plaintext sits briefly in dumps/ between runs; restic encrypts at rest, and
# this file only ever leaves the critical (encrypted) plan.
export_or_empty /tmp/n8n-credentials.json n8n export:credentials --all --decrypted
docker cp n8n:/tmp/n8n-workflows.json "$outdir/n8n-workflows.json.part"
docker cp n8n:/tmp/n8n-credentials.json "$outdir/n8n-credentials.json.part"
docker exec n8n rm -f /tmp/n8n-workflows.json /tmp/n8n-credentials.json

mv "$outdir/n8n-workflows.json.part" "$outdir/n8n-workflows.json"
mv "$outdir/n8n-credentials.json.part" "$outdir/n8n-credentials.json"
