# Plan — narrow the your_spotify `/api/*` edge bypass

Not a deployment. Closes the top open item from the 2026-07 security reviews
(`docs/future.md`). One Caddyfile edit, no compose change, no downtime. Delete this doc
when it lands.

## What's wrong today

`thriller-bark/caddy/Caddyfile` bypasses **the entire API** at the edge:

```caddyfile
		@your_spotify_api path /api/*
		handle @your_spotify_api {
			reverse_proxy 100.64.0.1:8095
		}
```

Everything the app can do is reachable unauthenticated from the internet, with only
your_spotify's own session checks in the way. `GET /api/global/preferences` has **no
middleware at all** — it is public, and the only thing preventing public account creation
is `allowRegistrations: false` inside the app. That setting must stay off, and this plan
is what makes it stop being the sole line of defence.

## What actually needs to be public

Read off the server source (`apps/server/src/routes/`, 2026-07-26). The image is
`lscr.io/linuxserver/your_spotify:1.20.0`, an all-in-one where an internal nginx serves
the SPA and strips `/api` before the Express router, so `/api/oauth/...` at the edge is
`oauth.ts` inside.

| edge path | middleware in source | needs bypass? |
|---|---|---|
| `/api/oauth/spotify` | none — starts the link flow | yes |
| `/api/oauth/spotify/callback` | `withGlobalPreferences` — **not** `logged` | yes |
| `/api/oauth/spotify/me` | `logged` | no |
| `/api/global/preferences` (GET) | none | **no — this is the hole** |
| `/api/me` | `optionalLoggedOrGuest` | no |
| everything else | `logged` / `admin` | no |

So the bypass shrinks from `/api/*` to `/api/oauth/*` — two endpoints instead of the
whole surface.

## The change

```caddyfile
	@your_spotify host spotify.siffreinsigy.me
	handle @your_spotify {
		# Spotify redirects the browser back here; the link flow must not hit the portal.
		@your_spotify_oauth path /api/oauth/spotify /api/oauth/spotify/callback
		handle @your_spotify_oauth {
			reverse_proxy 100.64.0.1:8095
		}
		handle {
			forward_auth 127.0.0.1:9091 {
				uri /api/authz/forward-auth
				copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
			}
			reverse_proxy 100.64.0.1:8095
		}
	}
```

Both branches stay wrapped in their own `handle {}` — the mutual-exclusion rule that
broke the n8n webhook bypass. Note the paths are **exact, not `/api/oauth/*`**:
`/api/oauth/spotify/me` is a logged endpoint and there is no reason to hand it out.

## Why the SPA still works

The Authelia cookie is set on `*.siffreinsigy.me`, so the SPA's XHR calls to `/api/...`
are same-origin and carry it — `forward_auth` passes them through without the app noticing.

Two consequences to accept rather than discover:

- **On session expiry the UI breaks oddly** rather than redirecting: an XHR gets a 302 to
  the portal, which the SPA cannot follow usefully. A page reload fixes it. Single user,
  acceptable.
- **The public-token / guest-sharing feature stops working through the edge.** Endpoints
  guarded by `isLoggedOrGuest` and `optionalLoggedOrGuest` are now behind Authelia, so a
  shared stats link handed to someone else will hit the portal. If you ever want that
  feature, it needs its own bypass — deliberately, and written down here.

## Verify — all four, from a private window

```bash
curl -sI https://spotify.siffreinsigy.me/api/global/preferences | head -1   # expect 302 → portal
curl -sI https://spotify.siffreinsigy.me/api/me                  | head -1   # expect 302 → portal
curl -sI https://spotify.siffreinsigy.me/api/oauth/spotify       | head -1   # expect 302 → accounts.spotify.com
```
Then, logged in: the dashboard loads and charts render, and **re-link the Spotify account
end to end** — that is the only real test of the callback path.

Deploy is the usual `up -d --force-recreate` on the caddy stack via Komodo Sync, never
`caddy reload`.

## Done when

`/api/global/preferences` and `/api/me` answer with a redirect to Authelia from
off-session, the Spotify link flow completes, the dashboard works logged in, and
`docs/future.md`'s first open security item is deleted along with this file.
