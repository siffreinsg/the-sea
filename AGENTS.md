# AGENTS.md

## Working style

- Be concise. I search docs myself — guide in broad steps, don't pre-explain; help when I'm stuck.
- I have **no SSH access from here**. Hand me commands to run and I paste the output back.
- Challenge plans against new facts. They're broad strokes written upfront, not truth. Say so when one is wrong.
- Root-cause fixes, not symptom patches. Grep every caller before editing a shared path.

## Infra rules that bite

- **Never bind `0.0.0.0`** — `127.0.0.1` on TB, `100.64.0.1` on GM. Docker publishes past the firewall.
- **Every `pre_deploy` and `backup.sh` starts with `umask 077`.** Decrypted secrets and dumps must be 0600.
- **Never pass a secret as a CLI argument** (`~/.bash_history`, `ps`). Prompt instead.
- **Pin every image** to a released tag, and prefer alpine/slim variants.
- A new decrypt target needs a `.gitignore` entry in the same commit.
- Read the docs before proposing infra changes — most traps are already written down.

## Where docs go

| Kind | Location |
|---|---|
| **Why** a choice was made | `docs/decisions/YYYY-MM-DD-slug.md` + a row in its `README.md` |
| **How** a layer works, and its rules | `docs/domains/<domain>.md` |
| **What to type**, repeatable | `docs/runbooks/` |
| **Constants** — addresses, ports, schedules | `docs/reference.md` |
| One-off commands worth keeping | `docs/runbooks/commands.md` |
| In-flight app deployment | `docs/plans/` — **delete when it lands** |
| Deferred / wishlist | `docs/future.md` |
| Session state, what's half-done | `docs/HANDOFF.md` — untracked, never committed |

## Maintaining them

- **Rationale lives in the decision record only.** Domain docs state the rule and link to the ADR. Two copies drift — that's what this structure replaced.
- **New decision** = new dated file (context, decision, consequences, ~10 lines) + one index row. Date = the day it was decided.
- **Reversed a decision?** Mark the old one `Superseded by <link>`, never delete it. Why it was reversed is worth more than the original.
- **Test for anything written mid-session:** would a fresh clone need this? Yes → `domains/` or `decisions/`. No → HANDOFF.
- Audit reports and reviews are session artifacts: triage, dispatch the durable parts, delete the report, merge the branch **squashed**.
- Deleting beats adding. If a doc restates another, cut it.
