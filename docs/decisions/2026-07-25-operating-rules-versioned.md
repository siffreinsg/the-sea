# Operating rules are versioned; HANDOFF stays local

**2026-07-25 · Accepted · `3a39e61`**

`docs/HANDOFF.md` is gitignored and always has been. For a while it also held every
hard-won operating rule — the rclone-rw rationale, never-delete-the-GM-node, the Proton
429 stagger, the inode-pin pattern. The DR model is "clone the repo and drop the age
key", and a fresh clone recovered none of it.

The durable rules moved into committed docs. HANDOFF keeps session state only: what is
in flight, what is half-done, what to pick up next.

**Consequence:** the test for anything written during a session is "would a fresh clone
need this?" If yes it belongs in `docs/domains/` or a decision record here, not in
HANDOFF. Audit reports are session artifacts: triage them, dispatch the durable parts,
delete the report, merge the branch squashed so it never enters history.
