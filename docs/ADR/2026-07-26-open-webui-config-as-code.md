# Open-WebUI is configured as code, not through its Admin UI

**2026-07-26 · Accepted**

Open-WebUI reads most of its settings from the environment **once**, on first boot, then
persists them into its SQLite database, which wins on every later start
(`config.py` ~L2750–3135, `ENABLE_PERSISTENT_CONFIG` defaults `True`). Editing the env
file afterwards is a silent no-op — the failure mode being that `ENABLE_SIGNUP=False`
looks set in git while signup is still open in the running app.

**Decision: `ENABLE_PERSISTENT_CONFIG=False`.** `thriller-bark/open-webui/config.env` is
the single source of truth, reviewable in a diff, and `secrets.env` (SOPS) holds the four
values that can't be. The `ENABLE_OAUTH_SIGNUP` true-then-false first-login step only
works at all under this setting; left at the default it would be decorative.

Cost, accepted knowingly: the Admin UI still lets you edit those settings and silently
discards them on restart, no warning shown. Anyone changing behaviour must change the file
and redeploy. Two conventions keep the file readable: upstream defaults are never
written (a line means "this differs from v0.10.2"), and settings worth trying when
something breaks ship as commented-out lines with a one-line why.

Rejected: persistence on, UI as source of truth — puts real config inside a volume,
invisible to review, recoverable only from a restic snapshot.
