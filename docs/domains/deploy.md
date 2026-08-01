# Deploys

Komodo Core on TB drives Compose stacks from this repo, over the mesh, onto both Docker
nodes ([why Komodo and not Kubernetes](../ADR/2026-07-18-komodo-compose-not-kubernetes.md)).

## What belongs in one stack

A stack is one ship dir, one `compose.yaml`, one redeploy. What goes inside it is decided
by **who consumes the service**, not by how many containers it takes.

- **Private dependency → same stack.** A database, cache or worker that exists only to
  serve one app ships with it. Dawarich's Postgres, Redis and Sidekiq; your_spotify's
  Mongo; Grafana with VictoriaMetrics, Loki and Tempo.
- **Consumed by more than one app → own stack**, joined by `ai-backends` (or `edge` if
  Caddy needs it too) and reached by service name. LiteLLM, Tika. Alloy is separate for
  the same reason: every stack feeds it, and it is per-node.
- **Databases are always private**, one per app, inside the app's stack
  ([why](../ADR/2026-07-28-one-database-per-app.md)). No shared network, no host port.
  Name it `<app>-db`, never `postgres` — several stacks would otherwise publish the same
  short name and DNS on a shared network becomes ambiguous.

The point is blast radius. Redeploying Open-WebUI must not restart the model proxy that
n8n is using; nothing is gained by restarting Loki without Grafana.

## Resource sync

- The sync declares **stacks and repos, not servers** — servers come from Periphery
  onboarding. Do **not** add `[[server]]` blocks.
- Keep the sync **non-prune**, so it cannot delete what it did not create.
- A stack's `pre_deploy` can chain several decrypts with `&&` (see Authelia). Only encrypt
  files that actually hold secrets, and always prefix `umask 077 &&`
  ([why](secrets.md)).
- `KOMODO_DISABLE_CONFIRM_DIALOG=true` turns most confirmations into a double-click.

## `/opt/the-sea` on the nodes

Stacks deploy from Komodo's own per-stack checkout, never from `/opt/the-sea`. That
directory exists for the things Komodo doesn't run: `backups/run.sh` and each
`backup.sh`, the systemd units, the firewall unit, and the hand-managed `komodo` stack.

Two `[[repo]]` resources in `komodo/resources.toml` pin it to `/opt/the-sea` on each node
with a GitHub webhook, so a push to `main` syncs both. Consequences:

- **Komodo owns the checkout and hard-resets it.** Never hand-edit there.
- Untracked and gitignored files survive a pull (verified on a canary) — which is what
  keeps the in-tree volume dirs and the hand-made `komodo/.env` alive.

## Periphery

Periphery is a **systemd binary** on the hosts, not a container, because it execs `sops -d`
as `pre_deploy` and needs the age key. It runs as **root** with `SOPS_AGE_KEY_FILE` set, so
it can decrypt every secret in the repo and execute arbitrary commands.

Onboarding is **outbound** — it dials `wss://komodo.siffreinsigy.me/ws/periphery` — so
nothing listens today. Even so, each node's `periphery.config.toml` must carry
`bind_ip` = that node's mesh IP and `allowed_ips = ["100.64.0.0/10"]`, mode 0600, so a
later flip to inbound is safe by default. The shipped defaults are `[::]` with an empty
`allowed_ips` and no passkeys, which by the file's own comment is an **unauthenticated
root-RCE listener**. Never restore them.

Komodo Core's `network_mode: host` comment claims it needs the mesh for periphery agents —
unverified, and outbound-only onboarding above suggests it may not. Confirm empirically
before relying on either claim (`runbooks/deploy-a-stack.md`'s cutover pre-flight).

## The inode trap

**A bind-mounted git-tracked file is inode-pinned.** `git pull` swaps the inode, so a plain
`up -d` keeps serving the old content. Every stack mounting a single tracked config file
carries `extra_args = ["--force-recreate"]` (Caddy also `--build`).

Backrest correctly **omits** it: its only single-file mount is the locally generated
`rclone.conf`, which `git pull` never touches. That asymmetry is deliberate, not an
oversight.

After a Caddyfile change it is `up -d --force-recreate`, never `caddy reload`.

## Deploying by hand

Running `docker compose` on a host **skips** Komodo's `pre_deploy` decrypt. Decrypt first:

```bash
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sops -d secrets.env > .env
sudo chmod 600 .env
```

## Updating the control plane

The `komodo` stack is [deliberately not managed by Komodo](../ADR/2026-07-25-komodo-stack-hand-managed.md),
so it is the one thing you update by hand, on TB:

```bash
cd /opt/the-sea && git log -1                   # confirm the repo resource pulled your push
# edit thriller-bark/komodo/compose.yaml from the dev machine, commit, push, pull again
cd /opt/the-sea/thriller-bark/komodo
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sops -d secrets.env > .env   # no pre_deploy here
sudo chmod 600 .env
sudo docker compose up -d                       # plain up -d; no single-file bind mounts
docker logs --tail 30 komodo-core
```

Three traps:

1. `resources.toml` changes **never** reach this stack — including the `umask 077` every
   other stack gets for free.
2. A `sops -d` here needs the manual `chmod`, because there is no `pre_deploy` hook.
3. An edit made only on-node is invisible to git and will be clobbered by the next pull.

Pin `komodo-core` to the version **already running** unless you mean to upgrade — read it
with `docker exec komodo-core /usr/local/bin/core --version`. The `:2`-style floating tag
means an upstream release lands unreviewed on the component that can execute root commands
on both nodes.
