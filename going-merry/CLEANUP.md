# Going Merry — deep cleanup briefing

For a Claude Code agent running **on Going Merry** (amd64 OpenVZ VPS, sudo available). Goal: strip GM down to a clean Docker host managed by Komodo, **preserving bind-mount data dirs** so each app is re-imported on the fly when redeployed as a Komodo stack.

## Context

- GM runs years of legacy Docker services. They're being migrated to Komodo GitOps (repo `the-sea`, cloned at `/opt/the-sea`).
- Komodo Periphery (systemd binary) is already installed and **connected to Core** — leave it running.
- User has a manual archive backup and accepts downtime. No live backup step needed.
- All legacy app data is **host bind mounts**. The only exception was **bazarr** (rclone plugin mount to Sunny's media) — that setup is being abandoned; its data/config is disposable.

## Hard rules — never touch

- **Bind-mount source directories.** For every container, read its `Mounts[].Source` (host paths). Those are the app data — they must survive. Never `rm` anything under them.
- `periphery.service`, `tailscaled`, `docker` itself.
- `/etc/komodo`, `/etc/sops` (age key `root:600`), `/opt/the-sea`.

## Steps

1. **Record before removing.** Write `going-merry/legacy-inventory.md`: for each running/stopped container — name, image, published ports, and every bind `Source→Destination`. This is the redeploy reference (which dir maps where when recreating the stack in Komodo). Get it from `docker ps -a` + `docker inspect`. Print the full list of bind Source paths and confirm each is a data dir to KEEP before deleting anything.
2. **Stop + remove all legacy containers.** `docker stop $(docker ps -q)` then `docker rm $(docker ps -aq)`. (Data stays — it's on the host bind dirs.)
3. **Prune images / networks / build cache.** `docker system prune -a` (NOT `--volumes` — leave any named volumes for now unless clearly bazarr/rclone junk you've confirmed disposable).
4. **Remove the dead plugin remnants** from the kernel/time-namespace crash: `sudo rm -rf /var/lib/docker/plugins.broken` and any leftover rclone plugin/config + bazarr's abandoned mount.
5. **Sweep legacy launch mechanisms** so nothing auto-restarts the old stack: old `docker compose` project dirs, legacy `systemd` units, and cron entries that started these services. List each with its path and what it did in the inventory file before removing; leave anything you're unsure about and flag it.
6. **Report:** what was removed, what data dirs remain (with sizes, `du -sh`), and the app→bind-dir map for redeployment.

## After cleanup

Migration is per-app: deploy the Komodo stack pointing `env_file`/volumes at the preserved bind dir, verify it reads the old data, move on. bazarr gets rebuilt from scratch later.
