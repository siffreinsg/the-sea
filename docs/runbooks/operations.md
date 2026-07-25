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
  `wss://komodo.siffreinsigy.me/ws/periphery`). **Each node's `periphery.config.toml`
  must carry `bind_ip` = that node's mesh IP and `allowed_ips = ["100.64.0.0/10"]`,
  mode 0600**, so a later flip to inbound is safe by default. Shipped defaults are
  `[::]` with
  an empty `allowed_ips` and no passkeys — by the file's own comment that is an
  **unauthenticated root-RCE listener**, inert only while onboarding is outbound.
  Never restore those defaults; Periphery runs as root with `SOPS_AGE_KEY_FILE`.
- **The `komodo` stack is not managed by Komodo** (bootstrap order: it would be
  redeploying itself). It is the one stack with no `[[stack]]` entry, so it runs from
  `/opt/the-sea/thriller-bark/komodo/` — a user-owned checkout that drifts silently.
  `git -C /opt/the-sea pull` before touching it, and remember `resources.toml` changes
  never reach it.
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
- **Every `pre_deploy.command` starts with `umask 077`.** Without it the decrypted
  outputs land 0644 and the whole sops+age design buys nothing on-node — the OIDC
  token-signing private key, `CF_API_TOKEN` and the restic/rclone credentials were all
  world-readable until 2026-07-25. Same reason `thriller-bark/backups/run.sh` sets it.
  A new decrypt target must also be added to `.gitignore`: one `git add -A` in a clone
  where the Authelia decrypt has run commits the signing key to history forever.
- **Never pass a secret as a CLI argument.** It lands in `~/.bash_history` and in `ps`.
  Authelia's `crypto hash generate` prompts when `--password` is omitted.
- **Komodo stores its git PAT unencrypted in Mongo**, so the nightly
  `komodo-mongo.archive.gz` *is* a credential for the repo — and the repo is the trust
  boundary for root execution (see Backups). `/var/backups/the-sea/dumps` is 0700 for
  that reason. Same for n8n's `--decrypted=true` credential export beside it.
- **Secrets or hashes needing the app's own CLI** (argon2 passwords, pbkdf2 OIDC
  client secrets): there's no Docker on the dev machine, so `docker exec <container>`
  on-node, then set the value locally with `sops set '<path>' '"<value>"'` — avoids a
  full decrypt/re-encrypt round trip. Plain secrets (session keys, DB passwords) are
  generated locally with `openssl rand`.
- **Backrest's `config.json` is deliberately not in git**, even unencrypted — a real
  export carries a live bcrypt hash and an Ed25519 private key. Its repos and plans
  stay UI-managed, not GitOps.
- **Komodo alerters are UI-managed for the same reason.** An `[[alerter]]` block holds
  its webhook URL in the clear, and Komodo's secret interpolation only reaches builds,
  deployments and repos — never alerter endpoints. So the Discord alerter lives in the
  Komodo UI and is *not* in `resources.toml`; non-prune sync leaves it alone. It is one
  of the few things a DR clone won't recreate — re-add it by hand. **The same holds for
  three Procedures** (`Backup Core Database`, `Global Auto Update`, `Rotate Server Keys`)
  **and one Tag** — UI-only, Mongo-only, and `Global Auto Update` in particular changes
  what runs on both nodes. All four are DR gaps to recreate by hand.

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
  missing once and silently broke container-stats scraping on TB only. Accepted risk.
  Its real blast radius: `/:/rootfs:ro` lets Alloy read **`/etc/sops/age.key`**, so an
  Alloy compromise yields every secret on the node regardless of file modes. File
  hygiene below is defence-in-depth, not the mitigation — the mitigation would be
  fronting docker.sock with a proxy, not tightening permissions.
- **Everything sops writes on-node must be `600`.** `sops -d … > file` uses root's
  default `022` umask, so the decrypted `.env`/`rclone.conf` lands world-readable while
  the age key is correctly `600` — the decrypt step throws the protection away. Every
  `pre_deploy` in `komodo/resources.toml` is prefixed `umask 077 &&`; keep it there.
  Same for `backup.sh`: DB dumps are app data in the clear (Dawarich's is a full GPS
  history). Audit with
  `find /etc/komodo /var/backups/the-sea -type f \( -name '.env' -o -name 'rclone.conf' -o -name '*.gz' \) -perm -o=r`
  — expect no output. `umask` only affects **new** files, so a mode fix on existing ones
  is a one-time `chmod`, not a redeploy.
- **`/etc/komodo/periphery.config.toml` holds the onboarding key in cleartext** and is
  outside the sops pattern. Keep it `600` (Periphery runs as root, so it loses nothing).
  The same file has terminals enabled, which is how Komodo works — meaning **Komodo
  Core's own authentication is load-bearing for root on both nodes.**
- **Inbound firewall: 4747 only on GM; 80/443 are TB's alone.** GM carried a leftover
  ufw "Nginx Full" allow from the nginx-proxy-manager era until 2026-07-25. It mattered
  because default-deny is what makes a `0.0.0.0` bind mistake survivable — on those two
  ports it wouldn't have been.
- **VictoriaMetrics has no auth and Loki runs `auth_enabled: false`**, both on the
  mesh. That rests on the mesh being single-tenant and trusted — and it currently
  **isn't**: Docker's per-bridge MASQUERADE plus Tailscale's `ts-forward` accept means
  every bridged container on TB routes onto `100.64.0.0/10`, so n8n (a workflow engine
  that runs user code) can read the whole fleet's metrics and *every container's logs
  on both nodes*, and reach GM's mesh binds behind Caddy and Authelia. Headscale has no
  ACL policy, so the tailnet is allow-all. Open, tracked in `specs/future.md`.
- **The host firewall does protect the host from its own containers** — the iptables
  INPUT default REJECT gives `EHOSTUNREACH` from a container to `172.x.0.1` on 9120 /
  27017 / 2019, and every Docker publish is loopback-scoped, so Docker's usual
  publish-past-the-firewall problem doesn't apply. Keep both properties.
- **Caddy's admin API (`127.0.0.1:2019`) is unauthenticated read/write config** for any
  local user. `admin off` isn't available because Alloy scrapes it
  (`thriller-bark/alloy/config.alloy`); needs a dedicated loopback metrics site first.
- **Reboot to activate kernels.** `unattended-upgrades` installs but does not reboot
  unless `Automatic-Reboot` is set; TB carried seven uninstalled-into kernel releases
  for a month. `/var/run/reboot-required` is the thing to check.
