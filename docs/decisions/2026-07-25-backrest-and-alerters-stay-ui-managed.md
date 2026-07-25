# Backrest config and Komodo alerters stay UI-managed

**2026-07-25 · Accepted · `21f2415`**

Two exceptions to "everything in git", both for the same reason: committing them would
put a live secret in the repo in cleartext.

- **Backrest's `config.json`** — a real export carries a live bcrypt hash and an Ed25519
  private key. Repos and plans stay UI-managed.
- **Komodo alerters** — an `[[alerter]]` block holds its webhook URL in the clear, and
  Komodo's secret interpolation reaches builds, deployments and repos only, never alerter
  endpoints.

**Consequence:** these are the things a DR clone will *not* recreate, so they must be
rebuilt by hand — along with three Komodo Procedures and one Tag that are also UI-only.
The plan-assignment table in [backups](../domains/backups.md) is the only written record
of what Backrest is configured to do; keep it current.
