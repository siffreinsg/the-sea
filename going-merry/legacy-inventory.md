# Going Merry — legacy inventory

The **redeploy reference**: which host dir maps where when each app is recreated as a Komodo stack.

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
