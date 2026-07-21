# TB DB dumps

Nightly consistent dumps of TB's live databases, feeding the Backrest bulk plan.
Host systemd timer (not an in-stack sidecar) — the native scheduler, catches
missed runs, logs to journald.

Each service owns its dump: `thriller-bark/<service>/backup.sh`. `run.sh` globs
`thriller-bark/*/backup.sh` and runs each, so **adding a stateful service = drop a
`backup.sh` in its dir** — no edits here. Everything runs from the repo checkout,
so `git pull` updates the logic with no reinstall.

- `komodo/backup.sh` → `mongodump` out of the running container (password never leaves it).
- `headscale/backup.sh` → SQL `.dump` of the sqlite db via host `sqlite3` against the named volume.

Output: `/var/backups/the-sea/dumps/{komodo-mongo.archive.gz,headscale.sql.gz}` —
one file per DB, overwritten nightly (restic keeps the 7d/4w/6m history), written
atomically so a failed run keeps the last good file.

## Install on TB (once)

```bash
sudo apt-get install -y sqlite3            # host dep for the headscale dump
cd /opt/the-sea && git pull
sudo ln -sf /opt/the-sea/thriller-bark/backups/the-sea-dumps.service /etc/systemd/system/
sudo ln -sf /opt/the-sea/thriller-bark/backups/the-sea-dumps.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now the-sea-dumps.timer
```

Verify: `sudo systemctl start the-sea-dumps.service` then
`ls -lh /var/backups/the-sea/dumps/` — both files present, non-trivial size.
`systemctl list-timers the-sea-dumps.timer` shows the next 03:00 UTC run.
