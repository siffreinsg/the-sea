# Plan — Syncthing (Thriller Bark)

File sync hub for the Obsidian vault and project folders. Follows
`docs/runbooks/add-a-service.md`; deltas only. Delete this doc when it lands.

**This is the one service that breaks the bind rule**, deliberately and in exactly one
place. Read [the decision](../ADR/2026-07-26-syncthing-public-port.md) before
touching the compose file — the `0.0.0.0` on 22000 is not a mistake to be tidied up.

**Node TB.** Not because TB is the right disk — it isn't, ~2.4k write IOPS against GM's
41k — but because TB is the only node that can hold a public listener, and at least one
sync peer cannot join the mesh. ~20 GB (vault + projects) on a 193 G volume is fine on
capacity; Syncthing's writes are bursty rather than sustained, which is the shape TB
tolerates. If the tree ever grows past ~50 G or the disk shows up in Grafana, revisit —
the alternative is an nftables DNAT from TB to GM, rejected today as too much machinery.

**Pin, revised 2026-08-02:** `lscr.io/linuxserver/syncthing:v2.1.2-ls226`, not upstream's
own `syncthing/syncthing:2.1.2` image. Upstream's `docker-entrypoint.sh` only `chown`s
`$HOME` non-recursively before dropping to `PUID`/`PGID` — the config volume is a separate
mount point it never touches, so the non-root process can't write `cert.pem` and the
container crash-loops on first boot (`chmod /var/syncthing/config: operation not
permitted`). LinuxServer's image handles PUID/PGID ownership recursively via its s6 init,
same app version (v2.1.2). arm64 confirmed on the tag.

**Syncthing 2.x is a major version.** The database moved from LevelDB to SQLite and the
log format changed. This is a fresh install, so there is no v1 migration to survive —
but do not read v1 documentation for anything below.

## 1. Ship dir — `thriller-bark/syncthing/`

```yaml
services:
  syncthing:
    image: lscr.io/linuxserver/syncthing:v2.1.2-ls226
    container_name: syncthing
    restart: unless-stopped
    hostname: thriller-bark
    environment:
      PUID: "1000"
      PGID: "1000"
    ports:
      - "0.0.0.0:22000:22000/tcp"    # BEP sync — the deliberate exception
      - "0.0.0.0:22000:22000/udp"    # QUIC
      - "127.0.0.1:8384:8384"        # GUI/API, for host-mode Alloy to scrape /metrics
    networks:
      - edge                         # GUI reached by Caddy over container DNS, no host publish
    volumes:
      - syncthing-config:/config
      - syncthing-data:/data
      - ./custom-cont-init.d:/custom-cont-init.d:ro

networks:
  edge:
    external: true

volumes:
  syncthing-config:
  syncthing-data:
```

**LSIO only auto-chowns `/config`.** `/data` is a separate named volume Docker creates
as `root:root`; the app user (uid 1000) can `mkdir` nothing under it until it's chowned.
Hit this creating the first folder from a phone (`mkdir /data/Tasker Backups: permission
denied`). `thriller-bark/syncthing/custom-cont-init.d/chown-data.sh` fixes it on every
boot — LSIO runs `/custom-cont-init.d/*.sh` as root before dropping to `PUID`/`PGID`, so
this survives `--force-recreate` and a DR restore onto a fresh volume, not just a one-off
manual `docker exec chown`.

No `secrets.env`, so **no `pre_deploy`** on the stack entry. Device IDs and folder
layout are runtime state in the config volume, not config-as-code — Syncthing has no
declarative config file worth versioning, and its GUI writes the same file it reads.
Same call as [Backrest and the alerters](../ADR/2026-07-25-backrest-and-alerters-stay-ui-managed.md).

**21027/udp (local discovery) is not published.** Broadcast discovery is meaningless on
a VPS and would only answer the local subnet.

## 2. Firewall — the part that isn't in the repo

Docker's publish rule opens the host path by itself, so the host firewall needs nothing.
**Verified 2026-08-02:** `nc -vz 141.253.109.196 22000` answered from off-network with no
VCN change — an existing security-list rule already covers it. The plan's assumption that
a new ingress rule was needed was wrong; the audit item in `docs/TODO.md` ("read the
Oracle VCN security list — hairpin NAT can't prove which layer closes what") is why this
was checked instead of assumed.

Afterwards `docs/REFERENCE.md`'s "Open ports" row reads **TB 80/443/22/22000**. Update it
in the same commit.

## 3. Settings — do these in the GUI on first boot, before adding any folder

The public port is only safe because of this list. Nothing here is optional.

| Setting | Value | Why |
|---|---|---|
| GUI user + password | set immediately | The GUI is behind `forward_auth`, but the container is also reachable from other containers on TB's bridges |
| Global discovery | **off** | Peers are configured with static addresses; nothing needs to announce this node to Syncthing's public servers |
| Relaying | **off** | Decided: full-speed direct connections, no third-party hop |
| NAT traversal (UPnP) | off | No UPnP on a cloud VPS |
| Usage reporting | off | |
| Default folder | remove it | The image creates `~/Sync`; delete it rather than let it sync |
| Metrics without auth | **on** | Lets host-mode Alloy scrape `/metrics` without a key; Caddy 404s the path at the edge so it's never public |
| **Folder defaults** (applies to every folder created after this) | | |
| Type | `sendreceive` | The rare one-way exception (e.g. a future service-integration folder) is set per-folder, not the default |
| File versioning | `simple`, 5 versions | Caps the footprint. Backrest is the real history, not this |
| Ignore patterns | `.DS_Store`, `node_modules`, `.venv`, `target`, `dist`, `build` | Don't replicate build output to every peer and into Proton |
| `ignorePerms` | **on** | Android and Windows peers have no meaningful Unix perms; syncing them causes spurious changes on every other peer |
| `minDiskFree` | 25 GiB (absolute, not %) | 193 G volume is shared with everything else on TB; a percentage default could let a runaway sync eat tens of GB before stopping |
| fsWatcher | on (default) | Real-time change detection; rescan interval stays at the 1h default as the fallback net |
| **Every folder path** | must start `/data/` | See below — this is the one that loses data |
| **Every device** | `autoAcceptFolders` off, `introducer` off | Manual accept per new folder/device is the actual security boundary — don't automate around it |
| Compression | `metadata` (default) | TB's constraint is disk IOPS, not bandwidth; `always` just burns CPU |
| Bandwidth limit | none | No data yet to size a cap against; add one only if the first sync actually causes contention |
| Folder naming | `id` = `label` = kebab-case slug matching the path segment (e.g. `obsidian-vault`) | Keeps the GUI list, `du -sh /data/*` and folder IDs trivially matched across 10+ folders |

**The folder-path trap.** The GUI defaults a new folder to the home directory
(`/config/<label>`), which is the **config volume, not the data volume**. Accept that
default and the sync tree lands inside `syncthing-config` instead of `syncthing-data`:
not lost on `--force-recreate` (both are real named volumes), but invisible to
Backrest's bulk plan (only `syncthing-data` is mounted there) and bloats a volume meant
to stay small. Set the path under `/data/` for every folder, and before trusting the
first snapshot confirm the bytes landed on the right volume:

```bash
docker exec syncthing du -sh /data/*
docker volume inspect syncthing_syncthing-data
```

Each peer device is added by device ID and **must be confirmed on both ends** — an
unknown device that connects to 22000 gets rejected and only shows up as a pending
request. That allowlist is the actual security boundary of the open port.

Peers pointed at this node use `tcp://141.253.109.196:22000`. A mesh-capable peer may use
`tcp://100.64.0.2:22000` instead and skip the public path — **that direction only.** Note:
`acl.hujson` has no GM→TB entry — it needs a second ACL block, `{"action":"accept",
"src":["tag:gm"],"dst":["tag:tb:22000"]}`, not a row appended to the existing TB→GM one.
Syncthing here is a bridged container on TB, so anything *it* dials on `100.64.0.0/10` is
DROPped by `the-sea-mesh-guard.service` in raw/PREROUTING. It works because peers connect
inbound to a listener that is always up, never because TB reaches out. Don't configure a
mesh address on the TB side and then debug the silence.

## 4. Caddy — GUI only, `forward_auth`

Syncthing's GUI has basic auth and no OIDC, so outcome **(b)** per
[the three auth outcomes](../ADR/2026-07-23-three-auth-outcomes.md). The sync
protocol does not go through Caddy at all — it is its own TLS on 22000.

```caddyfile
	@syncthing host syncthing.siffreinsigy.me
	handle @syncthing {
		forward_auth authelia:9091 {
			uri /api/authz/forward-auth
			copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
		}
		reverse_proxy syncthing:8384
	}
```

Check `syncthing.siffreinsigy.me` has no existing Cloudflare record before deploying —
the wildcard does not cover a name that already holds one.

## 5. Ignore patterns

Set these in each project folder before the first sync, or you will replicate build
output to every peer and into Proton:

```
(?d).DS_Store
node_modules
.venv
target
dist
build
```

`.stignore` lives inside the folder and syncs with it if you let it — that's usually what
you want.

## Backups

Decided: **the whole tree in the bulk plan, one entry.** Syncthing is replication, not
backup — a bad delete propagates to every peer in seconds, and restic's history is the
only thing that answers that.

Mount the data volume `:ro` into TB's Backrest (`thriller-bark/backrest/compose.yaml`),
alongside the existing `caddy-data` / `authelia-data` entries:

```yaml
      - syncthing-data:/userdata/syncthing:ro
...
  syncthing-data:
    external: true
    name: syncthing_syncthing-data
```

Then add `/userdata/syncthing` to TB's **bulk** plan in the Backrest UI (container-side
path, not host). The config volume is not backed up — device IDs are re-pairable and the
folder layout is a five-minute rebuild.

**Expect a ~20 GB first snapshot** out of TB's slow disk to Proton. Run it manually once
rather than discovering it at 04:00, and confirm it finished before trusting the
schedule.

## Monitoring

`/metrics` on the GUI/API port, same shape as LiteLLM's. GUI setting
`metricsWithoutAuth: true` lets host-mode Alloy scrape `127.0.0.1:8384` unauthenticated;
Caddy 404s `/metrics` at the edge so it's never public. Alert: `Syncthing folder stuck
out of sync` in `going-merry/observability/provisioning/alerting/rules.yaml`, firing when
a folder's `needBytes` stays above 0 for 6h. No per-device disconnect alert — the phone
is expected offline most of the time, and the stuck-folder alert already catches the
harm that matters regardless of which peer caused it.

**Verified 2026-08-02 against a live scrape:** `syncthing_model_folder_summary` uses
`scope="global"|"local"|"need"` and `type="bytes"|"deleted"|"directories"|"files"|"symlinks"`
— not an `item="needBytes"` label as first guessed. The alert's `expr` uses
`{scope="need",type="bytes"}`.

## Done when

The GUI gates through Authelia, a peer on the mesh and the peer that can't join the mesh
(Sunny) both show "Up to Date" — **done**, TB and Sunny paired — `nc -vz` from
off-network answers on 22000 — **done**, no VCN change needed — an unknown device ID is
refused, the tree appears in a TB bulk snapshot, and the phone's first folder synced
without error — **done**, after the `/data` chown fix.

Remaining: unknown-device rejection check, Backrest bulk-plan addition.
