# Backups: Backrest → restic → Proton Drive + Mega

**2026-07-21 · Accepted · `b6e7da0`**

restic encrypts client-side, so no storage provider ever sees plaintext, which makes
consumer cloud storage acceptable as a backup target. Backrest supplies scheduling and
a UI on top of it. rclone reaches the remotes.

Two tiers: **Proton Drive** takes everything backed up (bulk), **Mega** takes a second
copy of the critical subset only — finances, DB dumps, workflow exports, secrets
material. One independent Backrest per node; instance-sync (peer/hub) is deliberately
off, so nothing crosses nodes but encrypted restic traffic.

**Consequence:** the restic and Backrest passwords in the password manager are the DR
root of trust, alongside the age key. Media is not backed up — it is re-acquirable.
