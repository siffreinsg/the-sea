#!/usr/bin/env bash
# Docker volume sizes, as Prometheus metrics.
#
# Why this exists: cadvisor measures a container's *writable layer* only. Every byte that
# actually matters here — Postgres, Loki, VictoriaMetrics, Tempo, chat history — lives in
# a named volume, which cadvisor does not see at all. Without this, the resources
# dashboard would confidently point at the wrong culprit for a full disk.
#
# Written to the node_exporter textfile directory, which Alloy's embedded unix exporter
# reads on every scrape. Install: see docs/runbooks/db-dumps.md, same pattern.
set -euo pipefail
umask 022   # metrics are not secret; Alloy must read them

out=/var/lib/node_exporter/textfile/docker_volumes.prom
mkdir -p "$(dirname "$out")"

{
  echo '# HELP docker_volume_size_bytes Disk used by a Docker named volume.'
  echo '# TYPE docker_volume_size_bytes gauge'
  for d in /var/lib/docker/volumes/*/_data; do
    [ -d "$d" ] || continue
    v=$(basename "$(dirname "$d")")
    # du -s, one filesystem, block-size 1 — real blocks consumed, not apparent size
    b=$(du -s --block-size=1 --one-file-system "$d" 2>/dev/null | cut -f1) || continue
    printf 'docker_volume_size_bytes{volume="%s"} %s\n' "$v" "$b"
  done
} > "$out.part"
mv "$out.part" "$out"
