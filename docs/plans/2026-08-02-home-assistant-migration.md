# Home Assistant migration

Move HA off Baratie (HAOS on bare RPi) to a container on GM. Baratie becomes a Tailscale
subnet router plus a Komodo/Alloy node with no stacks assigned.

## Target state

- HA Core container on GM, under Komodo: `going-merry/home-assistant/`.
- Baratie: Raspberry Pi OS Lite. Advertises the home LAN as a Tailscale subnet route.
  Komodo Periphery + Alloy installed, joins as a fourth managed node, zero stacks assigned.
- `home.siffreinsigy.me` → Caddy (TB) → gm-relay → GM container. Direct proxy, no
  Authelia forward_auth — HA mobile app / Google Home / Alexa can't do an OIDC redirect.
  HA's own login is the only gate.
- Freebox port-forward to the RPi deleted once the container is live.
- Config rebuilt from scratch, not copied — HA Core and HAOS diverge enough (Supervisor
  add-ons, backup format) that copying `/config` risks dragging HAOS cruft in. Recorder
  history not migrated, fresh DB.

## Inventory (2026-08-02, via `/api/states` + `/api/config`)

- **Discovery-dependent, need a static IP post-move**: 4x Yeelight color bulbs (SSDP),
  Sony Bravia TV — registered under both `braviatv` and `androidtv_remote` (zeroconf).
- **Not affected by the LAN move** (cloud or local-API-key based, not discovery):
  Freebox (router integration), Plex (13 media_player entities), Spotify, PlayStation 5,
  Overseerr, Dawarich, Tautulli, Met weather.
- **6 automations carry over** (none device-discovery-dependent): sunrise-on-alarm, smart
  wake-up weekday, smart wake-up weekend, lights-off-when-away, Freebox overheat alert,
  plus the "left home with lights on" notify.
- **Dropped**: RPi under-voltage alert (host-specific, no RPi after the move), SpeedTest
  automation (its add-on is cut, see below), backup-failure alert (superseded — HA's
  config/DB joins GM's Backrest bulk plan, which already alerts on a failing dump per
  `domains/backups.md`).
- **Supervisor add-ons: all dropped, clean cut.** AdGuard Home, Let's Encrypt, Samba
  share, Studio Code Server, Advanced SSH & Web Terminal, Speedtest — none exist on a
  Container install and none get redeployed elsewhere. AdGuard's DNS role, if still
  wanted, is a separate decision outside this migration.
- **HACS**: one custom component, `dawarich` (companion sensors for the already-deployed
  Dawarich instance — not a new service, just a HACS integration to reinstall).
- **Linky** (Enedis power meter) — core integration, not HACS, reconfigure normally.
- Dashboard (5 views: Accueil, Lumières, Média & Jeux, Plex & Seerr, Réseau & Système) —
  rebuilt by hand, dropping anything wired to a cut add-on (AdGuard tiles, add-on update
  entities) or the RPi-specific host section.
- No manual `configuration.yaml` edits beyond the `yeelight.custom_effects` block (the
  Sunrise/Smart-Wakeup light transitions, referenced by the kept automations) and the
  Free Mobile SMS `notify` — both carry over.

## Steps

1. **Inventory — done.** Exports pulled via HA API + UI, see above.
2. Stand up HA Core container on GM (`going-merry/home-assistant/`), per
   `runbooks/add-a-service.md`.
3. Rebuild automations/dashboards/integrations from the inventory. Resolve flagged
   discovery devices with static IP / manual config as needed.
4. Wire `home.siffreinsigy.me` in Caddy + gm-relay, direct proxy, no Authelia.
5. Add HA's config volume + recorder DB dump to GM's Backrest bulk plan
   (`domains/backups.md` §3c convention).
6. Cut over: verify HA on the new container, then wipe Baratie to RPi OS Lite, set up
   Tailscale subnet-router advertisement for the home LAN, install Komodo Periphery +
   Alloy.
7. Delete the Freebox port-forward to the RPi, **and** delete `home.siffreinsigy.me`'s
   existing Cloudflare A record (it points straight at the Freebox's public IP today —
   that's how the current HA is reached — and sits outside the wildcard until it's gone;
   the Caddy block added in step 2 is inert until this record is removed).
8. Update docs in the landing commit: `nodes.md` (Baratie role/runtime, GM service list),
   `REFERENCE.md` (web-UI table, gm-relay table if HA needs a relay hop), `backups.md`
   (assignment table), `ARCHI.md` (Baratie leaves the "outside every diagram" paragraph).

## Open risk

The 4 Yeelight bulbs and the Sony Bravia TV are SSDP/zeroconf-discovered — they'll need
static IPs (or manual host entry in their integration config) once HA is off-LAN, since
discovery doesn't cross the Tailscale subnet route. Everything else in the inventory is
cloud or local-API-key based and unaffected.
