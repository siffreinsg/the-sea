# Plan — Paperless-ngx + Tika (Thriller Bark)

Document archive with OCR. Follows `docs/runbooks/add-a-service.md`; deltas only. Two
stacks, because Tika is shared. Delete this doc when both land.

**Depends on Syncthing** (`docs/plans/2026-07-26-syncthing.md`) — the consume folder is a
Syncthing folder, which is the whole intake design. Deploy Syncthing first.

## Placement — TB, and it's the third written exception

Intake is a Syncthing consume folder, Syncthing is on TB, and a consume directory has to
be a local path. That pins Paperless to TB, where the placement rule would have sent a
Postgres-backed app to GM.

It is a better fit than the rule suggests, which is why it's accepted rather than worked
around: **OCR is the dominant cost and it's CPU-bound** — TB is ~2× GM all-core (4950 vs
2474 events/s) — and TB has the larger disk (193 G vs 99 G). The Postgres here does a
handful of writes per document, not the sustained DB load the rule was written about. The
rejected alternative was a second Syncthing on GM syncing one folder over the mesh: more
moving parts than the problem.

Note the archive **grows without bound** and lands on the node whose disk is already the
scarce resource. Watch it in Grafana; the escape hatch is moving the media volume, not the
app.

## Pins, resolved 2026-07-26 — every manifest index inspected, all carry `linux/arm64`

| | image | note |
|---|---|---|
| Paperless-ngx | `ghcr.io/paperless-ngx/paperless-ngx:2.20.1` | **deliberately not the latest.** `v3.0.2` released 2026-07-24, two days old and a major bump. For an archive of personal documents, let a major settle. Re-evaluate on deploy day and take 3.0.x if it's aged well |
| Postgres | `postgres:17-alpine` | same as the pattern elsewhere |
| Redis | `redis:7-alpine` | required — it's the task broker, not a cache |
| Gotenberg | `gotenberg/gotenberg:8.34.0` | Paperless-only |
| Tika | already deployed, `apache/tika:3.3.1.0-full` — check `thriller-bark/tika/compose.yaml` for the current pin on deploy day | shared stack, don't redeploy at an older tag |

## 0. Reaching Tika: join `ai-backends`, not a host port

Tika is shared, so Paperless and Open-WebUI both have to dial it — and neither can do it
via `127.0.0.1`. From inside a bridged container `127.0.0.1` is *its own* loopback, and
the host gateway (`172.x.0.1`) is closed by TB's `INPUT` default REJECT, which
`docs/domains/networking.md` records as a deliberate property.

Tika, LiteLLM and Open-WebUI already share the pre-existing `ai-backends` network
([REFERENCE](../REFERENCE.md)) — Paperless's `webserver` joins it too and dials
`http://tika:9998` by container name. No ports published for Tika at all; nothing about
this crosses the host or the mesh. Does not affect Karakeep, which reaches LiteLLM over
[the public edge](../ADR/2026-07-27-cross-node-calls-use-the-public-edge.md) from another
node.

## 1. Tika — `thriller-bark/tika/`

Its own stack because two unrelated apps use it: Paperless for Office documents and
`.eml`, Open-WebUI for document extraction (`CONTENT_EXTRACTION_ENGINE=tika`,
`TIKA_SERVER_URL=http://tika:9998`). Bundling it inside Paperless would mean redeploying
Paperless breaks chat uploads.

Stateless, no volume, no secrets, no `pre_deploy`, **no Caddy route and no Authelia** —
like LiteLLM, it stays off the edge entirely. Only `ai-backends`, no published port.
Nothing to back up.

`-full` rather than the base tag: it carries the OCR and language models Paperless expects.
It is a JVM and will sit around 1 GB resident.

## 2. Paperless — `thriller-bark/paperless/`

No host port. `webserver` needs `container_name: paperless-webserver` set explicitly —
compose's default name for a service named `webserver` in project `paperless` doesn't
match, and both `edge`'s reverse_proxy target and the `docker exec` below assume it.

Four services: `webserver`, `db`, `broker`, `gotenberg`; only `webserver` joins networks
outside the stack's own — `edge` to be reached by Caddy, `ai-backends` to reach Tika.

Volumes: `data`, `media` (the documents — this is the one that matters), `pgdata`, and a
**bind mount** for consume:

```yaml
      - /var/lib/docker/volumes/syncthing_syncthing-data/_data/paperless-inbox:/usr/src/paperless/consume
```

Reaching into another stack's volume path is ugly; the alternative is declaring
`syncthing-data` as an external volume here and mounting a subpath, which is cleaner —
prefer that if the subpath mount works with this Docker version. Either way **it is
read-write**: Paperless deletes the file after ingesting, and that deletion propagates to
every Syncthing peer, which is exactly the desired behaviour.

Env worth naming:

| var | value |
|---|---|
| `PAPERLESS_URL` | `https://paperless.siffreinsigy.me` — set explicitly, or CSRF rejects the login POST behind the proxy |
| `PAPERLESS_SECRET_KEY` | `secrets.env`, `openssl rand -base64 48` |
| `PAPERLESS_REDIS` | `redis://broker:6379` |
| `PAPERLESS_DBHOST` / `DBUSER` / `DBPASS` | `db` + credentials from `secrets.env` |
| `PAPERLESS_TIKA_ENABLED` | `1` |
| `PAPERLESS_TIKA_ENDPOINT` | `http://tika:9998` |
| `PAPERLESS_TIKA_GOTENBERG_ENDPOINT` | `http://gotenberg:3000` |
| `PAPERLESS_OCR_LANGUAGE` | `fra+eng` |
| `PAPERLESS_TIME_ZONE` | `Europe/Paris` |
| `PAPERLESS_CONSUMER_POLLING` | `5` — **required.** Syncthing writes files in ways inotify across a bind mount misses; polling is the reliable path and the docs say so |
| `PAPERLESS_CONSUMER_RECURSIVE` | `1`, with `PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS=1` if you want folder-per-tag from your phone |
| `PAPERLESS_OCR_SKIP_ARCHIVE_FILE` | leave default — the archived searchable PDF is the point |

`pre_deploy.command = "umask 077 && sops -d secrets.env > .env"`.

## 3. Auth — OIDC, outcome (a)

Paperless does OIDC through django-allauth. The trap: **the provider is configured as a
JSON blob in a single env var**, `PAPERLESS_SOCIALACCOUNT_PROVIDERS`, and a malformed
value fails at startup rather than at login. It also needs
`PAPERLESS_APPS=allauth.socialaccount.providers.openid_connect`.

Shape (one line in `secrets.env`, since it embeds the client secret):

```json
{"openid_connect":{"APPS":[{"provider_id":"authelia","name":"Authelia","client_id":"paperless","secret":"...","settings":{"server_url":"https://auth.siffreinsigy.me/.well-known/openid-configuration"}}]}}
```

Redirect URI, where `authelia` is the `provider_id` above:
```
https://paperless.siffreinsigy.me/accounts/oidc/authelia/login/callback/
```
**Trailing slash included** — Django is strict about it. `require_pkce: true` with `S256`;
allauth supports it.

Set `PAPERLESS_DISABLE_REGULAR_LOGIN=true` and
`PAPERLESS_REDIRECT_LOGIN_TO_SSO=true` **after** the first SSO login has created and
linked your superuser. Create that superuser first —
`docker exec -it paperless-webserver python3 manage.py createsuperuser` — or you can lock
yourself out of a fresh instance.

`webserver` also joins `edge`; Caddy is a plain `reverse_proxy paperless-webserver:8000`
by container name, no host port needed. Check `paperless.siffreinsigy.me` has no existing
Cloudflare record.

## Backups — critical tier, both halves

Personal documents; this is the most irreplaceable data in the fleet after the secrets
material.

- `backup.sh` in the service dir: `pg_dump` inside the container into
  `/var/backups/the-sea/dumps/`, atomic `.part` + `mv`, `umask 077` first line. `chmod 600`
  if it exits via `docker cp`.
- The `media` volume `:ro` into TB's Backrest, and **into the critical plan, not bulk** —
  the DB alone is worthless without the files. Restic dedups, so after the first snapshot
  the incremental cost is small.
- `data` (the search index and thumbnails) is regenerable — skip it, said explicitly so
  nobody adds it later.
- Rejected: `document_exporter`. It writes a full second copy of the archive on TB's slow
  disk every run. Worth reconsidering *once*, by hand, if you ever want a
  version-independent copy — but not as the nightly path.

**A restore needs the same Paperless major version**, which is fine because the tag is
pinned in git — the pin is part of the restore procedure, not just a hygiene rule.

## Done when

A PDF dropped into the Syncthing inbox from a phone appears in Paperless with OCR'd
searchable text and disappears from the inbox on every peer; a `.docx` ingests (proving
Tika and Gotenberg); Open-WebUI extracts a document through the same Tika; login is SSO
with the regular form disabled; and a `pg_dump` plus the media volume both appear in a TB
**critical** snapshot.
