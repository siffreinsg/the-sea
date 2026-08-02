# AGENTS.md

Always load skills `docs-system` and `i-have-adhd`.
Read the `docs/HANDOFF.md` document for context on the previous session conclusions.

## Guidelines

- Be concise, lead with the answer.
- Prefer editing existing files over creating new ones.
- For multi-step tasks, work through them systematically.

## Working style

- No SSH access from here. Hand me commands to run, I paste the output back.
- Always challenge plans, decisions, remarks, ... Say so when one is wrong.
- Root-cause fixes, not symptom patches. Grep every caller before editing a shared path.

## Infrastructure

- Never bind `0.0.0.0`, bind `127.0.0.1` on TB, `100.64.0.1` on GM.
  Three exceptions: TB's Alloy OTLP receiver ([why](docs/domains/networking.md)),
  gm-relay's proxy ports ([why](docs/domains/networking.md)),
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
- Code and configs must be commented. Comments should be one or two lines.
- Never explain *why a rejected alternative was rejected* in a comment or doc unless a future
  reader would otherwise redo that mistake. State the decision, not the deliberation.
- Docs: state the fact once. No restating context already in a linked doc, no "as discussed
  above," no recap paragraphs before the point.
- Default doc/comment length: the shortest version that a future you, with zero memory of this
  conversation, needs to not re-derive the decision. Cut anything past that.
- If a section is a list, use the list. Don't also narrate it in prose above or below.

## Git

- `main` is write-protected. Use branches and PRs. Pay attention, branches are deleted after a PR is merged.
- Commit and push only when asked.
- Split commits by concern. A runbook fix, a set of plans and a decision reversal are three commits, not one. If two concerns touch the same file, group them rather than surgically splitting the diff.
- Commit subject: `type(scope): imperative summary`
- Commit body: the *why*, names the trap found and records what was rejected.
- Never add `Co-Authored-By` or session/tool trailers. Plain messages.
- `docs/HANDOFF.md` stays out of git.
- Nothing decrypted ever lands. New decrypt target gets its `.gitignore` entry **in the same commit** that introduces it. Check `git status` before committing, not after pushing.
- Delete landed plans from `docs/plans/` in the same commit that lands it, not a later tidy-up.
