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

The cost, accepted knowingly: **the Admin UI still lets you edit those settings and
silently discards them on restart.** Roughly 70% of the app's configuration surface
becomes read-only-by-silence, with no warning in the interface. Anyone changing behaviour
must change the file and redeploy.

Two conventions follow from it, and they are what keep the file readable:

- **Upstream defaults are never written.** A line in `config.env` means "this differs from
  v0.10.2", so the file is a diff against upstream rather than a dump.
- **Settings worth trying when something breaks ship as commented-out lines** next to what
  they relate to, each with a one-line why — so the reasoning survives without bloating
  the live config.

Rejected: leaving persistence on and treating the UI as the source of truth. It would put
the app's real configuration inside a volume, invisible to review and recoverable only
from a restic snapshot, which is the opposite of how every other service here is managed.
