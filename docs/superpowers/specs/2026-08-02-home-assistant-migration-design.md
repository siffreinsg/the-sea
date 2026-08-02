# Home Assistant migration — design

Move HA off Baratie (HAOS on bare RPi) to a container on GM. Baratie becomes a Tailscale
subnet router plus a Komodo/Alloy node with no stacks assigned.

## Architecture

- HA Core (not HAOS) runs as a Docker container on GM, under Komodo:
  `going-merry/home-assistant/`.
- Baratie: wiped to Raspberry Pi OS Lite. Advertises the home LAN as a Tailscale subnet
  route, so the GM container reaches LAN devices over the mesh. Also gets Komodo Periphery
  and Alloy installed, joining it as a fourth managed node (TB, GM, Baratie) — zero stacks
  assigned initially, brought in line with the deploy/observability pattern for consistency.
- Freebox port-forward to the RPi is deleted once the container is live. No public entry
  point on the LAN side survives the migration.

## Exposure

`home.siffreinsigy.me` → Caddy (TB) → gm-relay → GM container. Direct proxy, no Authelia
forward_auth — the HA mobile app, Google Home, and Alexa integrations can't complete an
OIDC redirect. HA's own login is the only gate, same as the RPi's setup today.

## Config migration

Rebuilt from scratch, not copied. Home Assistant Core and HAOS diverge enough (Supervisor
add-ons, backup format) that copying `/config` risks dragging HAOS-only cruft into a
container install.

**Inventory pass** (before the container exists), via the HA API (long-lived access
token, supplied by the user when this step starts — never as a CLI arg):
- Every automation, script, and dashboard.
- Every integration, plus which of them rely on mDNS/SSDP discovery vs. manual IP/API
  config — discovery breaks once HA is off-LAN behind a subnet route, and this is the one
  known risk of the move. Flagged devices get a static IP or manual integration config
  instead of relying on auto-discovery.
- Every HACS custom component.
- Any manual `configuration.yaml` edit not implied by the UI-generated config.

Recorder history is not migrated. Fresh database on the new install.

## Fit with existing infra patterns

- **Placement**: recorder DB writes are frequent small writes — the disk-I/O-heavy profile
  the placement rule sends to GM's fast disk, not TB's scarce one
  (`docs/domains/nodes.md`).
- **Backups**: HA's config volume and recorder DB dump join GM's Backrest bulk plan,
  following the existing per-service dump convention (`docs/domains/backups.md`,
  `docs/runbooks/add-a-service.md` §3c).
- **Docs to update on landing**: `nodes.md` (Baratie's role/runtime row, GM's service
  list), `REFERENCE.md` (web-UI table, gm-relay table if HA needs a relay hop),
  `backups.md` (assignment table), `ARCHI.md` (Baratie leaves the "outside every diagram"
  paragraph once it joins Komodo/Alloy).

## Open risk

mDNS/SSDP-discovered devices (Chromecast, Sonos, HomeKit, local-mode Tuya, etc.) may need
static-IP workarounds once HA is off-LAN. Not resolved here — the inventory step surfaces
which devices are actually affected before any workaround is designed.
