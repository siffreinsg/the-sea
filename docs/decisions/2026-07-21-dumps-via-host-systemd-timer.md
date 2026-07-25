# Database dumps run from a host systemd timer

**2026-07-21 · Accepted · `db9fd71`**

Backing up a live database file is how you restore a corrupt one. Every stateful service
gets a logical dump first, and Backrest picks the dumps up as ordinary files.

The scheduler is a host systemd timer per node, not an in-stack sidecar: it is the
native scheduler, it catches missed runs, and it logs to journald. `run.sh` globs
`<node>/*/backup.sh` from the repo checkout, so adding a stateful service means dropping
a `backup.sh` in its directory with nothing else to edit.

**Consequence:** the units run as **root**, and they run whatever the checkout contains —
the repo is the trust boundary for root execution on both nodes. That is why Komodo's
git token is read-only. Dumps land an hour before the first backup plan.
