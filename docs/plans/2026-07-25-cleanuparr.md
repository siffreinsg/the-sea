# Plan — Cleanuparr (Going Merry)

Queue janitor for the arr stack. Follows `docs/runbooks/add-a-service.md`; deltas only.
Delete this doc when it lands.

**Node GM.** Image `ghcr.io/cleanuparr/cleanuparr:2.9.16` (the ghcr tag has no `v`
prefix, unlike the GitHub release). Bind `100.64.0.1:11011`. Host
`cleanuparr.siffreinsigy.me`. Docs were read at that tag, not `main`.

**Jobs in scope: Queue Cleaner, Malware Blocker, Discord notifications.** Download
Cleaner (ratio/seed-time cleanup) stays off — seeding policy is the seedbox's business.

## The shape of this one: repo delta is thin, UI is where the work is

Cleanuparr keeps *all* configuration — arr instances, download client, job rules,
notification targets, even its own OIDC client secret — in a SQLite DB under `/config`,
edited through its web UI. There are no config files and **no `secrets.env`**: the
compose file carries only `PORT`/`PUID`/`PGID`/`UMASK`/`TZ`, and the stack entry has
**no `pre_deploy` sops step and no `env_file`** (an `env_file: .env` with nothing
generating `.env` is a deploy failure).

Consequence: pushing this repo change gets you a running, empty Cleanuparr. The
checklist at the bottom is the other half.

## Talking to Sunny

API-only, no media mount, no mesh — the Profilarr pattern. Sonarr/Radarr over their
public direct-connect URLs with API keys; qBittorrent over its Ultra.cc WebUI URL
(confirmed working from outside). Every connection is outbound from Cleanuparr;
nothing dials *in*, which is why the Caddy block needs no bypass paths.

**Both chosen jobs need the download client, not just the arrs.** Malware Blocker
inspects torrent contents; Queue Cleaner's stalled/slow rules read client state. If
qBittorrent is unreachable, Malware Blocker is dead and Queue Cleaner degrades to
failed-import handling only.

## Auth — Authelia OIDC client

Cleanuparr speaks OIDC natively: `client_secret_post` and **PKCE S256** (both read off
`OidcAuthService.cs`, not assumed), so `require_pkce: true` with
`pkce_challenge_method: S256`. Two redirect URIs, both needed:

- `https://cleanuparr.siffreinsigy.me/api/auth/oidc/callback` — login
- `https://cleanuparr.siffreinsigy.me/api/account/oidc/link/callback` — account linking

Set **Redirect URL** explicitly in the UI to `https://cleanuparr.siffreinsigy.me`;
don't rely on auto-detection behind a proxy (the Dawarich lesson).

**Accepted risk, first boot.** OIDC is configured *inside* the app, so it cannot exist
before the app does: from the moment Caddy serves the hostname until you finish setup,
the first-run account page is open to whoever reaches it. Claim the admin account as
the very first action after deploy.

**Leave Exclusive Mode off.** It disables password login entirely; if Authelia is down
you are locked out and the documented recovery is editing the database by hand.

## Backups

`/config` holds live credential material (qBittorrent password, arr API keys, Discord
webhook). Named volume `cleanuparr_config` mounted `:ro` into GM's Backrest at
`/userdata/cleanuparr`, added to **both** the GM bulk and critical plans — bulk is
everything, critical is the subset worth keeping when bulk gets trimmed.

## Observability

Nothing. Alloy discovers it via `docker.sock`; no app `/metrics` worth scraping.

## Post-deploy checklist (web UI, in order)

1. **Claim the admin account** the moment the stack is up — before anything else.
2. **General → Internet Connectivity Check: on.** Without it, an outage at GM looks
   like every download stalling at once and the queue gets shredded on strikes.
3. **Download Client** → qBittorrent, the Ultra.cc WebUI URL + credentials. Test it
   here; everything downstream depends on it.
4. **Arr → Sonarr and Radarr** (public URLs + API keys). Both instances if the anime
   Sonarr is separate.
5. **Queue Cleaner** — every 5 min (`0 0/5 * ? * * *`). Failed-import max strikes 3.
   One stalled rule and one slow rule to start; add nuance after watching it work.
6. **Malware Blocker** — hourly is plenty. Blocklist:
   `https://raw.githubusercontent.com/Cleanuparr/Cleanuparr/main/blacklist`
   (`blacklist_permissive` if it proves too aggressive).
7. **Private trackers:** `Ignore Private` **on** and `Delete Private` **off** for both
   jobs. Deleting a private torrent mid-seed earns H&R on the tracker account. Revisit
   deliberately, per rule, never as a default.
8. **Notifications → Discord** webhook URL. Nothing to store in the repo.
9. **Account → OIDC**: provider name `Authelia`, issuer `https://auth.siffreinsigy.me`,
   client id `cleanuparr`, the plaintext secret, redirect URL as above. Save, then
   **Link Account** so only your identity can sign in. Exclusive Mode stays off.

## Done when

A test download is struck and removed end to end, the removal lands in Discord, OIDC
login works from a fresh browser session, and `/config` shows up in a GM critical
snapshot.
