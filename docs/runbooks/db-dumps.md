# The nightly dump harness

Consistent logical dumps of every live database, feeding the Backrest plans. A host
systemd timer per node rather than an in-stack sidecar
([why](../decisions/2026-07-21-dumps-via-host-systemd-timer.md)).

**Each service owns its dump.** `run.sh` globs `<node>/*/backup.sh` and runs each, so
adding a stateful service means dropping a `backup.sh` in its directory — nothing here to
edit. Everything runs from the repo checkout, so `git pull` updates the logic with no
reinstall.

| Node | Dumps |
|---|---|
| TB | `komodo/` (mongodump), `headscale/` (sqlite `.dump`), `actualbudget/`, `n8n/` (workflow + credential export), `litellm/` (`pg_dumpall` — covers Open-WebUI's pgvector database too) |
| GM | `dawarich/` (`pg_dump`), `your_spotify/` (mongodump) |

Output goes to `/var/backups/the-sea/dumps/`, one file per DB, overwritten nightly —
restic keeps the 7d/4w/6m history. Writes are atomic (`.part` + `mv`), so a failed run
keeps the last good file.

**The directory is 0700 and every file in it 0600.** These dumps are plaintext app data,
and Komodo's carries the git token — see [secrets](../domains/secrets.md).

## Install (once per node)

```bash
sudo apt-get install -y sqlite3            # TB only — host dep for the headscale dump
sudo ln -sf /opt/the-sea/<node>/backups/the-sea-dumps.service /etc/systemd/system/
sudo ln -sf /opt/the-sea/<node>/backups/the-sea-dumps.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now the-sea-dumps.timer
```

`<node>` is `thriller-bark` or `going-merry`.

## Verify

```bash
sudo systemctl start the-sea-dumps.service
systemctl status the-sea-dumps.service --no-pager   # want inactive (dead), status=0
ls -l /var/backups/the-sea/dumps/                   # all files present, non-trivial, 0600
systemctl list-timers the-sea-dumps.timer           # next run 03:00 UTC
```

`run.sh` exits non-zero if any single dump fails, so the unit's state is the signal. Keep
it green: a unit that is permanently failed cannot tell you it has *started* failing, which
is exactly what happened while n8n's export errored on an empty database.
