# Operating rules

The durable, hard-won rules of this infra — the things a fresh clone plus the age
key does **not** teach you. Session state lives in the (untracked) `docs/HANDOFF.md`;
this file is the part that must survive a disaster recovery.

## Reference values

- Domain **siffreinsigy.me** (Cloudflare, DNS-only / grey cloud). ACME + Authelia
  user mail: `hello@siffreinsigy.me`.
- Mesh IPs — TB `100.64.0.2`, GM `100.64.0.1`. Mesh base domain `mesh.siffreinsigy.me`.
- age recipient `age1wce7sqneyq58tux6fnpj2e2tsc05j4jqk8h8dguu0jc6eplfrslqqdw7md`.
  Private key: password manager + `/etc/sops/age.key` (root, 600) on each node.
- Repo on nodes: `/opt/the-sea`, from `git@github.com:siffreinsg/the-sea.git`, `main`.
- GM legacy app data preserved at `/home/siffrein/docker-mei/` — map in
  `going-merry/legacy-inventory.md`.
- Backup schedules (UTC): TB bulk/critical 04:00/04:30, GM 05:00/05:30. Dumps timer
  03:00, an hour ahead of the first plan.
- Backrest UIs `https://backrest-{tb,gm}.siffreinsigy.me`. Instance and restic
  passwords in the password manager — **the DR root of trust**. Restic repos:
  `rclone:proton:restic/<node>` (bulk) + `rclone:mega:restic/<node>-critical`.
- Naming: restic repos, plans and Backrest instances use **full node names**
  (`thriller-bark`); only DNS and short-lived tags shorten (`backrest-tb`).

## Networking and binds

- Caddy and Komodo Core use `network_mode: host` (they must dial mesh addresses).
  Everything else binds a private address — `127.0.0.1` on TB, `100.64.0.1` on GM.
  **Never `0.0.0.0`.** Don't "fix" these to bridge networks.
- GM's `100.64.0.1` is a **procedural pin** — DB-persisted and stable across reboots,
  but it changes if the node is deleted and re-added. **Never delete that node**;
  re-register the existing one. The Caddyfile targets this IP directly.
- Anything on GM binding `100.64.0.1` must be ordered `After=tailscaled`.
- **GM runs an OpenVZ kernel you don't control** (the provider once dropped
  time-namespace support and crashed dockerd). Avoid kernel-exotic things there. Its
  `ifupdown-pre` / `systemd-networkd-wait-online` failures are benign OpenVZ noise.
- **DNS wildcards don't cover names that already have any record.** Standard DNS, not
  a Cloudflare quirk — a name holding even an unrelated MX record goes NODATA instead
  of falling through to `*.siffreinsigy.me`. Check the exact name in Cloudflare before
  picking a subdomain. Bit us twice on Authelia's hostname.

## Deploys

- Komodo resource sync declares **stacks and repos, not servers** — servers come from
  Periphery onboarding. Keep the sync **non-prune** so it can't delete them.
- Periphery is a **systemd binary** on the hosts, not a container, because it execs
  `sops -d` as `pre_deploy`. It uses **outbound onboarding** (dials
  `wss://komodo.siffreinsigy.me/ws/periphery`) — no bind_ip, no passkey. To flip a
  server to inbound later, set `bind_ip = "100.64.0.1"` on GM first.
- **A bind-mounted git-tracked file is inode-pinned.** `git pull` swaps the inode, so
  plain `up -d` won't pick the change up — every stack mounting a single tracked
  config file carries `extra_args = ["--force-recreate"]` (Caddy also `--build`).
  Backrest correctly omits it: its only single-file mount is the locally generated
  `rclone.conf`. After a Caddyfile change it's `up -d --force-recreate`, never
  `caddy reload`.
- Running `docker compose` by hand on a host **skips** Komodo's `pre_deploy` decrypt —
  decrypt manually first:
  `sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sops -d secrets.env > .env`.
- A stack's `pre_deploy` can chain several decrypts with `&&` (see Authelia). Only
  encrypt files that actually hold secrets.
- `KOMODO_DISABLE_CONFIRM_DIALOG=true` turns most confirmations into a double-click.
  Needs a redeploy of the `komodo` stack itself (plain `up -d`).
- **DR deploy order:** Backrest mounts four `external: true` volumes (headscale,
  caddy, komodo, observability) and won't start until those stacks have each been
  deployed once. Deploy the source stacks before `backrest-tb`.

## Secrets

- Encrypted `secrets.env` / `secrets.<name>` committed; decrypted `.env` on-node,
  gitignored. Decryption needs sudo (the age key is root:600).
- **Secrets or hashes needing the app's own CLI** (argon2 passwords, pbkdf2 OIDC
  client secrets): there's no Docker on the dev machine, so `docker exec <container>`
  on-node, then set the value locally with `sops set '<path>' '"<value>"'` — avoids a
  full decrypt/re-encrypt round trip. Plain secrets (session keys, DB passwords) are
  generated locally with `openssl rand`.
- **Backrest's `config.json` is deliberately not in git**, even unencrypted — a real
  export carries a live bcrypt hash and an Ed25519 private key. Its repos and plans
  stay UI-managed, not GitOps.

## Backups

- **Every stateful service gets a dump plus a plan entry** — see
  `runbooks/add-a-service.md` §3c for the mechanics.

**Who is in which plan.** Backrest's own config is deliberately not in git, so this
table is the only written record of the assignment — keep it current.

| Node | Critical (Mega) | Bulk (Proton) |
|---|---|---|
| TB | Authelia config + db, Actual Budget, n8n exports, `/userdata/caddy` (certs — belt-and-suspenders, beyond the ACME-recoverable scoping) | Komodo Mongo dump, headscale dump, the whole `/userdata/backups` dumps dir |
| GM | Dawarich (`pg_dump`) | your_spotify (`mongodump`), Grafana data, cold config dirs |

Both nodes' **bulk** plans include the dumps directory as a *directory* entry
(`/userdata/backups`), not a file list — so a new `backup.sh` is covered the moment it
runs, with nothing to add per-app. Note those paths are **container-side** mount
points as shown in Backrest's UI, not the host's `/var/backups/the-sea`.

Deliberately **not** backed up: media (re-acquirable), VM metrics and Loki logs
(retention-capped, 90d/30d), plexautolanguages' `/config` (Plex episode cache, cheaply
rebuilt), Homepage (all config is in git).
- **`rclone.conf` is mounted read-write**, not `:ro`, in both Backrest compose files.
  protondrive persists its refreshed OAuth token back into the file; a read-only mount
  broke that silently (`device or resource busy` on the rename) and probably caused an
  earlier Proton 401 cascade on TB. The committed encrypted copy is the
  reset-to-known-good baseline.
- **TB and GM authenticate to the same Proton account.** Simultaneous re-auths trigger
  `429 Too many recent logins` — that's why the schedules are staggered an hour apart.
  Keep the offset if you change them.
- **Backrest instance-sync (peer/hub) is deliberately off.** One independent Backrest
  per node; nothing crosses nodes but encrypted restic traffic.
- Dump units run as **root** and `run.sh` globs `<node>/*/backup.sh` from the repo
  checkout — anything landing a `backup.sh` in a service dir runs as root nightly. The
  repo is the trust boundary.

## App-level gotchas that cost real time

- **Don't write app config from memory. Pin the version, read that version's docs.**
  Authelia's schema moved hard at 4.38 (session became a `cookies:` array, JWT secrets
  moved under `identity_validation`, the forward-auth path changed). Same discipline
  for every OIDC integration.
- **A Rails app told its protocol is `https`** (`APPLICATION_PROTOCOL` or equivalent)
  will `force_ssl`-redirect anything without `X-Forwarded-Proto: https` — including
  its own container-internal healthcheck on loopback, which can never be HTTPS since
  TLS terminates at Caddy. The symptom looks like a raw TLS error, not a 301, and it
  blocks `depends_on: service_healthy` for sidekiq-alikes. Fix: send the header from
  the healthcheck too (`wget --header='X-Forwarded-Proto: https' ...`). Hit this on
  Dawarich; check it before blaming the kernel or the network.
- **A restored DB volume that skips `initdb` keeps its old password**, whatever the
  new compose sets — `POSTGRES_PASSWORD` only applies at cluster creation. Look for
  the old app's `.env` beside the data before generating a password nobody can use.
- **Caddy's `handle` mutual exclusion only applies between siblings.** A `handle`
  containing a nested `handle` *plus* trailing loose directives does not short-circuit
  — wrap every branch in its own `handle {}`. This is what broke n8n's webhook bypass.
- **Alloy is the widest-privilege container in the fleet** (host netns, `/` mounted,
  docker.sock — `:ro` on a socket only protects the file, the API is fully usable).
  It's necessary: cadvisor has no path-override args and needs `/rootfs`, `/sys`,
  `/var/lib/docker` **and `/run/containerd/containerd.sock` — that last one was
  missing once and silently broke container-stats scraping on TB only. Accepted risk,
  feed it to the security audit in `specs/future.md`.
- **VictoriaMetrics has no auth and Loki runs `auth_enabled: false`**, both on the
  mesh. Fine for a single-tenant trusted tailnet; revisit if the mesh ever gains a
  less-trusted node.
