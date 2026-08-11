# the-sea

Infrastructure-as-code for a self-hosted homelab across four nodes.

review: pr
autopilot: off
commits: `type(scope): imperative description`
deploy: Komodo GitOps from this repo · secrets: SOPS + age

## Skills

always: workflow

## Agents

Dispatch `worker`, `devil` and `newcomer` as the `workflow` skill describes, without asking
each time.

## Worktrees

When asked for work unrelated to what is in flight, propose `EnterWorktree` before touching
anything. Explain why in one line, wait for approval.

## Docs

Read `docs/PROJECT.md`, then `docs/TODO.md`.

## Project rules

- No SSH access from here. Hand me the commands to run, I paste the output back.
- Never bind `0.0.0.0`. Bind `127.0.0.1` on TB, `100.64.0.1` on GM. Three exceptions: TB's
  Alloy OTLP receiver and gm-relay's proxy ports ([why](docs/domains/networking.md)), and
  Syncthing's 22000, the only publicly reachable one
  ([why](docs/ADR/2026-07-26-syncthing-public-port.md)).
- Every `pre_deploy` and `backup.sh` starts with `umask 077`. Decrypted secrets and dumps are 0600.
- Never pass a secret as a CLI argument (`~/.bash_history`, `ps`). Prompt instead.
- Pin every image to a released tag, and prefer alpine/slim variants.
- A new decrypt target needs its `.gitignore` entry in the same commit.
