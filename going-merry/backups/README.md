# GM DB dumps

Nightly consistent dumps of GM's live databases, feeding the Backrest bulk plan.
Host systemd timer (not an in-stack sidecar) — the native scheduler, catches
missed runs, logs to journald. Mirrors `thriller-bark/backups/` — see that
README for the full rationale.

Each service owns its dump: `going-merry/<service>/backup.sh`. `run.sh` globs
`going-merry/*/backup.sh` and runs each, so **adding a stateful service = drop a
`backup.sh` in its dir** — no edits here.

- `dawarich/backup.sh` → `pg_dump` out of the running container.

Output: `/var/backups/the-sea/dumps/dawarich-postgis.sql.gz` — overwritten
nightly (restic keeps the 7d/4w/6m history), written atomically so a failed
run keeps the last good file.

## Install on GM (once)

```bash
cd /opt/the-sea && git pull
sudo ln -sf /opt/the-sea/going-merry/backups/the-sea-dumps.service /etc/systemd/system/
sudo ln -sf /opt/the-sea/going-merry/backups/the-sea-dumps.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now the-sea-dumps.timer
```

Verify: `sudo systemctl start the-sea-dumps.service` then
`ls -lh /var/backups/the-sea/dumps/` — dawarich-postgis.sql.gz present, non-trivial size.
`systemctl list-timers the-sea-dumps.timer` shows the next 04:00 UTC run.
