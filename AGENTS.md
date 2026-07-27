# AGENTS.md

Read the `docs/HANDOFF.md` document for context on the previous session.

## Working style

- I have **no SSH access from here**. Hand me commands to run and I paste the output back.
- Challenge plans against new facts. They're broad strokes written upfront, not truth. Say so when one is wrong.
- Root-cause fixes, not symptom patches. Grep every caller before editing a shared path.

## Infra rules that bite

- **Never bind `0.0.0.0`** — `127.0.0.1` on TB, `100.64.0.1` on GM. Docker publishes past the firewall.
  Two written exceptions, both reasoned: TB's Alloy OTLP receiver ([why](docs/domains/observability.md)),
  and Syncthing's 22000, the only *publicly reachable* one ([why](docs/decisions/2026-07-26-syncthing-public-port.md)).
  A third needs its own record.
- **Every `pre_deploy` and `backup.sh` starts with `umask 077`.** Decrypted secrets and dumps must be 0600.
- **Never pass a secret as a CLI argument** (`~/.bash_history`, `ps`). Prompt instead.
- **Pin every image** to a released tag, and prefer alpine/slim variants.
- A new decrypt target needs a `.gitignore` entry in the same commit.
- Read the docs before proposing infra changes — most traps are already written down.

## Where docs go

| Kind | Location |
| --- | --- |
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
- Always keep the HANDOFF minimal, point at docs instead. The point is to jump back in at the next session, not document everything that has been done.

## Keeping them short

- **Every line is a rule, a constant, a command, or a link.** Nothing else has a home here — no overview, no background, no recap, no prose that exists to sound thorough. Past tense is the tell: what *happened* goes in a commit message or an ADR, never a domain doc.
- **Every claim is checkable** against a config file, a command's output, or an ADR. If you can't point at what makes it true, cut it.
- **Line caps**: decision ≤ 30, runbook ≤ 80, domain ≤ 150, this file ≤ 80. Pure lists (`reference.md`, `runbooks/commands.md`) and `docs/plans/` are exempt. `future.md` is uncapped too — an entry there says what to decide and what breaks if it's wrong, and once it says *how*, it's a plan and moves to `docs/plans/`. Over cap isn't forbidden, it's a trigger: split or prune, and say which in the commit message.
- **Adding to a file means reading all of it first**, then deleting something stale in the same commit or stating that nothing was. Unbounded growth is append-without-read.
- **Docs are today's state, git is the archive.** Delete what stopped being true; the commit message names what went and why, so `git log -p -- <path>` and `git log -S '<term>'` can find it again. A message like `docs: cleanup` is what makes a deletion lossy.
- Two things never get deleted for brevity: superseded decisions (above), and constants — a port number costs one line, its absence costs a search.
- Same rules in config files. A comment earns its place by recording a trap or a non-obvious *why*; `# set the port` restates the line under it. Prefer one comment on the surprising block over one per key.

## Git

- **Work directly on `main`.** Solo repo, no PR flow. Don't branch, and don't open a PR, unless I ask or the work is a long audit/review (those get a branch and a **squashed** merge, per above).
- **Commit and push only when I ask.** Never mid-task, never "to be safe".
- **Split by concern, one commit per thing.** A runbook fix, a set of plans and a decision reversal are three commits, not one. If two concerns touch the same file, group them rather than surgically splitting the diff — but say in the message that you did.
- **Commit messages are prose, not a changelog line.** Subject is `type(scope): imperative summary`; the body says *why*, names the trap found, and records what was rejected. A future clone reads these to understand a choice it can't see in the diff.
- **Never add `Co-Authored-By` or session/tool trailers.** Plain messages.
- **`docs/HANDOFF.md` stays out of git.** It's gitignored and it stays that way — session state, not history. If something in it is still true next month, it belongs in `domains/` or `decisions/` instead, and *that* gets committed.
- **Nothing decrypted ever lands.** `.env`, `rclone.conf`, `users_database.yml`, `oidc.yml` are all gitignored; a new decrypt target gets its `.gitignore` entry **in the same commit** that introduces it. Check `git status` before committing, not after pushing.
- Deleting a landed plan from `docs/plans/` is part of the commit that lands it, not a later tidy-up.
