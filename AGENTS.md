# AGENTS.md

Read the `docs/HANDOFF.md` document for context on the previous session conclusions.

## Working style

- No SSH access from here. Hand me commands to run, I paste the output back.
- Always challenge plans, decisions, remarks, ... Say so when one is wrong.
- Root-cause fixes, not symptom patches. Grep every caller before editing a shared path.

## Infrastructure

- Never bind `0.0.0.0`, bind `127.0.0.1` on TB, `100.64.0.1` on GM.
  Two exceptions: TB's Alloy OTLP receiver ([why](docs/domains/observability.md)),
  and Syncthing's 22000, the only *publicly reachable* one ([why](docs/ADR/2026-07-26-syncthing-public-port.md)).
- Every `pre_deploy` and `backup.sh` starts with `umask 077`. Decrypted secrets and dumps must be 0600.
- Never pass a secret as a CLI argument (`~/.bash_history`, `ps`). Prompt instead.
- Pin every image to a released tag, and prefer alpine/slim variants.
- A new decrypt target needs a `.gitignore` entry in the same commit.
- Read the docs before proposing infra changes — most traps are already written down.

## Documentation

Always read the `docs-system` skill.

- Read `docs/TODO.md` first. It holds the answer to "What's next?"
- **How** the pieces fit and their rules: `docs/ARCHI.md` and `docs/domains/*.md`
- **Why** a choice was made: `docs/ADR/YYYY-MM-DD-slug.md`
- **What** to type and repeated procedures: `docs/runbooks/`
- **Constants** (addresses, ports, schedules, ...): `docs/REFERENCE.md`
- In-flight work, picked up from TODO: `docs/plans/`, delete when it lands
- Ideas, backlog: `docs/FUTURE.md`
- Session state, what's half-done: `docs/HANDOFF.md`

## Git

- Work on `main`, no PR flow except when explicitly asked for.
- Commit and push only when asked.
- Split commits by concern. A runbook fix, a set of plans and a decision reversal are three commits, not one. If two concerns touch the same file, group them rather than surgically splitting the diff.
- Commit subject: `type(scope): imperative summary`
- Commit body: the *why*, names the trap found and records what was rejected.
- Never add `Co-Authored-By` or session/tool trailers. Plain messages.
- `docs/HANDOFF.md` stays out of git.
- Nothing decrypted ever lands. New decrypt target gets its `.gitignore` entry **in the same commit** that introduces it. Check `git status` before committing, not after pushing.
- Delete landed plans from `docs/plans/` in the same commit that lands it, not a later tidy-up.
