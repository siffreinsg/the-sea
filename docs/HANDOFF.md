# Handoff — state as of 2026-07-18 (night)

Read this first in a new session. Delete or update it as work progresses.

## Where things stand

- **Spec is final**: `docs/specs/foundation-design.md`. Deferred items: `docs/specs/future.md`. No open questions left in the spec.
- **Plan 1 written, not started**: `docs/plans/2026-07-18-foundation-core.md` — mesh (Headscale) + ingress (Caddy) + secrets (SOPS) + deploy (Komodo), 9 tasks, ends with a whoami canary proving the full chain. Plans 2 (backups) and 3 (observability) are intentionally not written yet — write each after the previous executes.
- **Nothing is deployed.** Thriller Bark is fresh/nearly empty; Going Merry runs legacy services untouched.

## Key decisions (don't re-litigate)

- Mesh: **Headscale** on Thriller Bark behind Caddy. GM joins in **kernel mode** (OpenVZ host has `/dev/net/tun`) — its services bind GM's tailscale IP `100.64.0.1`, not localhost; Sunny stays userspace (no root). Decision confirmed by bidirectional listener test 2026-07-19.
- Domain: **siffreinsigy.me** (Cloudflare, DNS-only). ACME mail: siffr.hdesigy@gmail.com.
- Caddy and Komodo Core use `network_mode: host` (must dial mesh addresses); other services bind a private address — `127.0.0.1` on TB, GM's tailscale IP `100.64.0.1` on GM. Never `0.0.0.0`. Deliberate — don't "fix" to bridge networks.
- Komodo Periphery = systemd binary on hosts (not container), because it execs `sops -d secrets.env > .env` as pre-deploy.
- Secrets: encrypted `secrets.env` committed, `.env` decrypted on-node (gitignored). age key: password manager + `/etc/sops/age.key` per node.

## Next actions (in order)

1. **Execute Plan 1, starting Task 1** (Cloudflare token + wildcard DNS). Execution split agreed in spirit: human does SSH/dashboard steps, Claude writes repo files and commits ahead. Exact mode (task-by-task vs. write-all-files-first) was **not chosen** — ask.
2. **Going Merry deep clean** (sidelined, strategy agreed — see memory `going-merry-cleanup-strategy`): Phase 1 = read-only inventory by a Claude agent running *on* GM (repo will be cloned there), output `going-merry/legacy-inventory.md`. Claude should write the agent briefing `going-merry/CLEANUP.md` first — offered, not yet done. Phase 2 (deletions) only after Plan 2 backups exist, per-app during migration.
3. After Plan 1 executes: write Plan 2 (backups), then Plan 3 (observability).

## Loose ends

- `.vscode/` is untracked — user's call whether to commit or gitignore.
- Nothing pushed tonight unless the user pushed; check `git log origin/main..main`.
