# Going Merry — legacy inventory (pre-cleanup snapshot)

Recorded 2026-07-19 before the deep clean. This is the **redeploy reference**: which host dir maps
where when each app is recreated as a Komodo stack.

All surviving app data is under `/home/siffrein/docker-mei/` — **preserved in full**, plus the two
archives `/home/siffrein/docker-mei.tar.gz` (7.6G) and `/home/siffrein/minecraft.tar.gz` (5.6G).

Legacy compose files live beside the data in the same tree (`docker-mei` is its own git repo), so
each app's original config is recoverable from there.

## App → bind-dir map

Paths below are relative to `/home/siffrein/docker-mei/` unless absolute. No container published
any host port (all reached over the `revproxy` network via nginx-proxy-manager).

| Container | Image | Bind source → destination |
| --- | --- | --- |
| `dawarich_sidekiq` | `freikin/dawarich:latest` | `dawarich/dawarich_public` → `/var/app/public`<br>`dawarich/dawarich_storage` → `/var/app/storage`<br>`dawarich/dawarich_watched` → `/var/app/tmp/imports/watched` |
| `dawarich_app` | `freikin/dawarich:latest` | `dawarich/dawarich_db_data` → `/dawarich_db_data`<br>`dawarich/dawarich_public` → `/var/app/public`<br>`dawarich/dawarich_storage` → `/var/app/storage`<br>`dawarich/dawarich_watched` → `/var/app/tmp/imports/watched` |
| `dawarich_db` | `postgis/postgis:17-3.5-alpine` | `dawarich/dawarich_db_data` → `/var/lib/postgresql/data`<br>`dawarich/dawarich_shared` → `/var/shared` |
| `dawarich_redis` | `redis:7.4-alpine` | `dawarich/dawarich_shared` → `/data` |
| `webserver` (nginx-proxy-manager) | `jc21/nginx-proxy-manager:latest` | `webserver/data` → `/data`<br>`webserver/letsencrypt` → `/etc/letsencrypt` |
| `authentik_server` | `ghcr.io/goauthentik/server:2025.10` | `authentik/media` → `/media`<br>`authentik/custom-templates` → `/templates` |
| `authentik-worker-1` | `ghcr.io/goauthentik/server:2025.10` | `authentik/certs` → `/certs`<br>`authentik/media` → `/media`<br>`authentik/custom-templates` → `/templates`<br>`/var/run/docker.sock` → `/var/run/docker.sock` |
| `authentik-postgresql-1` | `postgres:16-alpine` | `authentik/postgresql` → `/var/lib/postgresql/data` |
| `actual_server` | `actualbudget/actual-server:latest-alpine` | `actualbudget/data` → `/data` |
| `code-server` | `lscr.io/linuxserver/code-server:latest` | `code-server/config` → `/config`<br>`code-server/workspace` → `/workspace` |
| `hedgedoc` | `lscr.io/linuxserver/hedgedoc:latest` | `hedgedoc/config` → `/config` |
| `n8n` | `docker.n8n.io/n8nio/n8n` | `n8n/data` → `/home/node/.n8n`<br>`n8n/files` → `/files` |
| `your_spotify` | `lscr.io/linuxserver/your_spotify:latest` | *(none — env-only)* |
| `your_spotify_mongo` | `mongo:6-jammy` | `your_spotify/db` → `/data/db`<br>anon volume `77a12eb6…` → `/data/configdb` |
| `portainer` | `portainer/portainer-ce:alpine` | `portainer/data` → `/data`<br>`/var/run/docker.sock` → `/var/run/docker.sock` |
| `diun` | `crazymax/diun:latest` | `diun/data` → `/data`<br>`diun/diun.yml` → `/diun.yml`<br>`diun/blackpearl.yml` → `/blackpearl.yml`<br>`/var/run/docker.sock` → `/var/run/docker.sock` |
| `cleanuparr` | `ghcr.io/cleanuparr/cleanuparr:latest` | `blackpearrl/cleanuparr/config` → `/config` |
| `configarr` | `ghcr.io/raydak-labs/configarr:latest` | `blackpearrl/configarr/config` → `/app/config`<br>`blackpearrl/configarr/repos` → `/app/repos`<br>`blackpearrl/configarr/templates` → `/app/templates` |
| `wizarr` | `ghcr.io/wizarrrr/wizarr` | `blackpearrl/wizarr/data` → `/data` |
| `PlexAutoLanguages` | `remirigal/plex-auto-languages:latest` | `blackpearrl/plex_auto_languages/config.yaml` → `/config/config.yaml`<br>anon volume `77b3e47d…` → `/config` |

### Data dirs with no container (config preserved, not currently deployed)

`blackpearrl/huntarr` (788M), `blackpearrl/maintainerr` (1.6M), `blackpearrl/bazarr2` (7.5M),
`games/mc-survie` (883M, also in `minecraft.tar.gz`), `revproxy` (372M).

### Intentionally discarded (deleted by the user before cleanup — not recovered)

- `open-webui` — host dir `docker-mei/open-webui/webui` deleted while the container ran; not in the
  archive (archive postdates the deletion). Confirmed intentional.
- `proton-mail` — host dir `docker-mei/proton-mail/data` deleted. Confirmed intentional.
- Compose files deleted but recoverable from `docker-mei` git if ever wanted:
  `open-webui/`, `proton-mail/`, `duplicati/`, `photon/`, `blackpearrl/apprise-api/`.

## Legacy launch mechanisms

| Path | What it did | Action |
| --- | --- | --- |
| user crontab (`siffrein`) | `0 0 * * 0 ./docker-mei/blackpearrl/configarr/run.sh` — weekly `docker compose run --rm configarr`, would recreate a container post-cleanup | removed |
| user crontab (`siffrein`) | `# 0 3 * * * …/kometa/run.sh` — already commented out | removed (dead) |
| systemd | no legacy unit found; only `docker`, `periphery`, `tailscaled`, `tailscale-wait-online` | left running |
| container restart policies | `unless-stopped` / `on-failure` on most containers | neutralised by removing the containers |

Compose project dirs under `docker-mei/` are **kept** (they hold the data and are the redeploy
reference); nothing auto-starts them once the containers and the cron entry are gone.

## Plugin / rclone remnants

- `/var/lib/docker-plugins/rclone` — data dir of the dead rclone managed plugin (root-owned).
- `/var/lib/docker/plugins.broken` — remnant of the plugin crash, if present (root-owned).
- `/usr/bin/rclone` + `/home/siffrein/.config/rclone/rclone.conf` + `/home/siffrein/.cache/rclone`.
- `bazarr2`'s `media` volume (`driver: rclone`, remote `blackpearl:media`) — the abandoned mount.
  The volume is already absent from `docker volume ls`; only the compose reference remains.

> The rclone config held a **plaintext SFTP password** for `axiom.usbx.me` (user `siffreinsg`).
> It was printed to a terminal during this cleanup — rotate that credential.

---

# Cleanup report (2026-07-19)

Disk: **69G → 22G used** on a 99G volume (~47 GB reclaimed). Verified after a reboot.

## Docker

Removed all 22 legacy containers, all 40 images, both anonymous volumes, all 10 custom networks,
and the build cache. End state: 0 containers / 0 images / 0 volumes, only the default
`bridge` / `host` / `none` networks, no plugins. Storage driver `overlay2` on extfs.

The rclone managed plugin, its data dir (`/var/lib/docker-plugins/rclone`), `plugins.broken`,
the `rclone` package and its configs were all removed. bazarr's abandoned `media` volume is gone.

## System packages

- **48 packages** purged: `john`/`john-data`, `bonnie++`, `speedtest`, `logcheck`, `dselect`,
  `software-properties-common`, `apt-transport-https`, `dkms` + kernel headers +
  `linux-compiler-gcc-12-x86` (inert on OpenVZ — the 4.19 kernel comes from the host),
  `initramfs-tools*`, `klibc-utils`, `docker-ce-rootless-extras`, `sshfs`/`fuse3`/`libfuse2`,
  `libx265-199`/`libgd3`/`libheif1`, the certbot python stack, the full build toolchain
  (`gcc`/`g++`/`cpp` 10 & 12, `make`, `binutils`, `dpkg-dev`), `packagekit`, and the exim stack.

  > `exim4` is only a metapackage — purging it leaves the daemon running. The packages that actually
  > matter are `exim4-daemon-light` + `exim4-base` + `exim4-config` (and `bsd-mailx` follows them out).
  > Port 25 stays bound until those go.
- **31 pre-bookworm orphans** purged (Debian 9→10→12 residue): `libpython3.7-*`, `python3.7-minimal`,
  `libperl5.28`, `perl-modules-5.28`, `libssl1.1`, `libncurses5`/`libtinfo5`, `libapt-pkg5.0`,
  `gcc-8-base`/`libgcc1`, `sysv-rc`/`insserv`/`initscripts`/`startpar`, `multiarch-support`, etc.
- Files: `/usr/local/bin/docker-compose` (Compose **v1**, 2020), `/opt/containerd` (2020 orphan),
  `/etc/cron.daily/*.disabled`.

Also purged: 32 packages left in `rc` state (removed, configs retained) by much older experiments —
nginx modules, python2.7/3.9, java, avahi, qt5, aufs-tools, resolvconf, x11-common.

Package count: **374**, zero `rc` leftovers. `/usr/local/bin` now holds only `periphery` + `sops`;
`/opt` only `the-sea`.

**Deliberately kept** (removal would break things): `libdb5.3` (dependency breakage), `libgpm2`
(would uninstall `vim`), `libncurses6` (current bookworm, not an orphan), `cpio` (`tar` reverse-dep).

## Verified intact (post-reboot)

`docker`, `containerd`, `periphery`, `tailscaled`, `ssh`, `cron` — all active + enabled after reboot.
Mesh healthy: `going-merry` 100.64.0.1, `thriller-bark` 100.64.0.2.
`/etc/komodo`, `/etc/sops`, `/opt/the-sea`, `docker-mei/` (4.3G) and both archives preserved.

Final listener set — nothing else is bound:

| Listener | Purpose |
| --- | --- |
| `62.4.16.10:4747` | `sshd` — non-standard port, **intentional host access**, do not touch |
| `0.0.0.0:41641` udp | tailscaled |
| `100.64.0.1:58436`, `[fd7a:…]:59780` | tailscale peerapi (mesh-only) |

Nothing binds `0.0.0.0` on a service port, as the foundation design requires.

### Known-benign failed units

`ifupdown-pre.service` and `systemd-networkd-wait-online.service` fail on this host. These are
**OpenVZ artifacts, not cleanup fallout**: networking is `venet`-managed via ifupdown, so
`networkd-wait-online` has nothing to wait for and `ifupdown-pre` chokes on the non-standard
interface. Neither unit comes from a removed package (`ifupdown-pre` ships with `ifupdown`, the other
with `systemd`). They persist across reboots with networking fully functional. Safe to ignore, or
silence with `systemctl disable systemd-networkd-wait-online.service`.

## Open items

- **Rotate the leaked `axiom.usbx.me` SFTP password** (see note above) — the only real action left.
- `periphery.config.toml` is still the stock file (`bind_ip = "[::]"`). Harmless while outbound mode
  is active (`core_address` set ⇒ inbound server off), but Task 7 of the foundation plan specifies
  `bind_ip = "100.64.0.1"`. Worth aligning before enabling inbound mode.
