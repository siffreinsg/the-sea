# Add a service

The repeatable pattern. Every new service is a **ship dir** (compose + secrets), a
**stack entry**, a **Caddy handle block** with **auth**, a **backup entry** if it's
stateful, and one **sync + deploy**. No per-service DNS — the wildcard
`*.siffreinsigy.me` already resolves to Thriller Bark.

**Before writing any config: pin the image to a released tag and read *that*
version's docs.** Never write app config from memory — Authelia's schema moved
hard at 4.38, and floating `:latest` plus Komodo's update polling silently
advances the running version. Also check Cloudflare for an existing record at the
subdomain you picked: a name with **any** record (even an MX) is no longer covered
by the wildcard.

`<node>` = `thriller-bark` (TB) or `going-merry` (GM). Pick a unique host port `<P>`.

## 1. Ship dir — `<node>/<app>/`

`compose.yaml`:
```yaml
services:
  <app>:
    image: <image>
    container_name: <app>
    restart: unless-stopped
    env_file: .env
    ports:
      - "<bind>:<P>:<container-port>"
```
`<bind>` is the node's private address — **never `0.0.0.0`**:
- **TB:** `127.0.0.1` (Caddy is on the same host).
- **GM:** `100.64.0.1` (GM's mesh IP — reachable from TB's Caddy over the mesh, off the public interface).

Services that must dial mesh addresses themselves use `network_mode: host` instead
(like Caddy and Komodo Core) — most don't.

Containers that must dial each other **by name** join `the-sea-internal` (TB only), which
is `external: true` everywhere and hand-created — `docker network create the-sea-internal`
if it is missing. Nothing recreates it, including DR.

`secrets.env` (skip if the app has no secrets):
```bash
cat > <node>/<app>/secrets.env <<'EOF'
FOO=bar
EOF
sops -e -i <node>/<app>/secrets.env
```
Decryption on-node is handled automatically by the stack's `pre_deploy` hook below;
Periphery already has `SOPS_AGE_KEY_FILE` in its systemd env.

## 2. Stack entry — append to `komodo/resources.toml`

```toml
[[stack]]
name = "<app>"
[stack.config]
server = "<node>"
git_account = "siffreinsg"
repo = "siffreinsg/the-sea"
branch = "main"
run_directory = "<node>/<app>"
pre_deploy.command = "umask 077 && sops -d secrets.env > .env"   # omit if no secrets.env
```
Do **not** add `[[server]]` blocks — servers come from Periphery onboarding, not
the sync. Keep the Sync in **non-prune** mode.

## 3. Caddy handle block — `thriller-bark/caddy/Caddyfile`

Inside `*.siffreinsigy.me`, above the final `handle { abort }`:
```caddyfile
	@<app> host <app>.siffreinsigy.me
	handle @<app> {
		reverse_proxy <bind>:<P>
	}
```
`<bind>` matches the compose bind: `127.0.0.1` for a TB app, `100.64.0.1` for a GM app.

## 3b. Auth — pick one of three

Default policy is `two_factor`; one Authelia cookie on `*.siffreinsigy.me` gives SSO
across everything. Pick by the app's capability, in this order:

**a) App supports OIDC** → make it an Authelia client (native login button, real
identity, no double-gate). Caddy stays a plain `reverse_proxy`.

```bash
# secret + its hash: Authelia's own CLI, in the running container.
# Omit --password: the CLI prompts. Passing it on the command line puts the
# plaintext in ~/.bash_history and in `ps` output for every local user — the
# 2026-07-25 TB review found the SSO password and three client secrets there.
docker exec -it authelia authelia crypto hash generate pbkdf2 --variant sha512
# adding a whole client: open the file, append to the clients array
sops thriller-bark/authelia/secrets.oidc.yml
```
If a tool ever leaves you no choice but to put a secret on the command line, prefix
that line with a **leading space** — `HISTCONTROL=ignoreboth` keeps it out of
`~/.bash_history`. That's a backstop, not the plan; prefer the prompt.
**Add a client by editing the file, not with `sops set`** on the `clients` path — it
holds every existing client, and setting it replaces the array wholesale, silently
deleting the live ones. `sops set` is for a **single scalar** at an indexed path
(e.g. filling in one client's hashed secret) — that's the round-trip-saving trick,
and it's safe only because it targets a leaf.

One client entry = `client_id`, `client_secret` (hashed), `redirect_uris`,
`require_pkce` (`false` if the app doesn't implement it — harmless on a
confidential client). The plaintext secret also goes in the app's `secrets.env`.
**Set the app's redirect URI explicitly**; don't trust its auto-derivation from a
hostname env var (bit us on Dawarich).

**b) No OIDC** → Caddy `forward_auth`:

```caddyfile
	@<app> host <app>.siffreinsigy.me
	handle @<app> {
		forward_auth 127.0.0.1:9091 {
			uri /api/authz/forward-auth
			copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
		}
		reverse_proxy <bind>:<P>
	}
```

Need to bypass paths (API, webhooks, OAuth callbacks)? **Wrap every branch in its
own `handle {}`.** Caddy's mutual exclusion only applies between *sibling* `handle`
blocks — mixing a nested `handle` with trailing loose directives silently doesn't
short-circuit (this is what broke the n8n webhook bypass). See the `your_spotify`
block for the working shape.

**c) App has its own login + 2FA judged sufficient** → neither. n8n went this way;
double-login friction wasn't worth it. Record the decision, don't leave it implicit.

**d) No humans at all — a GM service consumed by a TB container.** Then it gets no
hostname, no Caddy `handle` block and no auth, and §3 above does not apply. It cannot be
dialled directly either: the mesh guard DROPs `172.16.0.0/12 → 100.64.0.0/10`, so a bridged
container on TB reaching `100.64.0.1` times out. Add a relay listener instead
([why](../ADR/2026-07-29-caddy-relays-mesh-services-to-containers.md)):

```caddyfile
:<relay-port> {
	reverse_proxy 100.64.0.1:<P>
}
```

Outside the `*.siffreinsigy.me` block, at the bottom of the Caddyfile with the other
relays. The consumer uses `http://host.docker.internal:<relay-port>` and needs
`extra_hosts: - "host.docker.internal:host-gateway"`, never a literal `172.x`. Allocate the
port in [REFERENCE](../REFERENCE.md#caddy-mesh-relay) and add a row.

If the callee *does* authenticate itself (LiteLLM's virtual keys, an API key), the public
edge is the other sanctioned path — same ADR.

## 3c. Backups — mandatory if stateful

- **Live DB** → drop a `backup.sh` in the service dir writing to
  `/var/backups/the-sea/dumps/` (pattern: `going-merry/dawarich/backup.sh` — atomic
  `.part` + `mv`, dump inside the container). `run.sh` sets `umask 077` so the dump
  lands 0600 — **but if it leaves the container via `docker cp` rather than a stdout
  pipe, `chmod 600` it yourself**: `docker cp` carries the container-side mode across
  and the umask never applies. Bit the n8n export. The node's `run.sh` globs it up
  automatically, no edits. The dumps dir is already a Backrest source on both nodes,
  so nothing to add per-app there.
- **Cold config dir/volume** → mount it `:ro` into that node's Backrest
  (`<node>/backrest/compose.yaml`) and add it to the bulk plan in Backrest's UI.
  Backrest source paths in the UI are **container-side** (`/userdata/...`), not host
  paths.
- Sensitive data (finances, secrets material, workflow exports) also goes in the
  node's **critical** plan.
- Genuinely re-creatable cache (e.g. plexautolanguages' `/config`) → skip, but say so
  in the plan doc.

## 4. Ship it

```bash
git add <node>/<app> komodo/resources.toml thriller-bark/caddy/Caddyfile \
        thriller-bark/authelia/secrets.oidc.yml   # if you added an OIDC client
git commit -m "feat(<app>): deploy on <node>" && git push
```
Then:
- **Komodo:** Execute the `the-sea` Sync (or let the GitHub webhook fire it) → the new
  stack appears → **Deploy** it. Watch the deploy log; the `pre_deploy` sops step is
  where a missing/rotated key shows up.
- **Caddy (TB)** — Komodo Sync deploys `caddy` automatically (`extra_args =
  ["--force-recreate", "--build"]` avoids the stale-inode issue from `git pull`
  swapping the Caddyfile — never `caddy reload`).

## 5. Observability — usually nothing to do

Both nodes' Alloy discovers **all** containers via `docker.sock` — no allowlist.
For any new service this is automatic, zero config:

- **Logs** land in Loki, labeled `container=<app>`, `node=<node>`. Explore →
  Loki → `{container="<app>"}`.
- **Container resource metrics** (CPU/mem/net) land in VictoriaMetrics via
  cadvisor, same labels — dashboard **14282** already covers any container.

Only add something if the app exposes its **own** `/metrics` endpoint you
want scraped (app-level counters, not container resource usage). Then, in
that node's `config.alloy`:

```alloy
prometheus.scrape "<app>" {
  targets    = [{ __address__ = "127.0.0.1:<metrics-port>", job = "<app>" }]
  forward_to = [prometheus.relabel.add_node.receiver]
}
```

**On GM the address is `100.64.0.1:<metrics-port>`, not `127.0.0.1`** — GM services bind
the mesh address per the bind rule, and Alloy is `network_mode: host` so it reaches them
directly. If the endpoint needs credentials, add `basic_auth` with
`password = sys.env("...")`, give the stack a `secrets.env` and a `pre_deploy`, and add
`env_file: .env` to its compose (`going-merry/alloy` is the worked example).

Commit, push, Komodo Sync → Deploy `alloy-tb`/`alloy-gm`.

No Grafana-side action either way — no per-service datasource, dashboard, or
provisioning step. Only build a dedicated dashboard if 1860/14282/Explore
don't answer a real question you have.

## 6. Verify

```bash
curl -s https://<app>.siffreinsigy.me
```
For a GM app, a successful response with `RemoteAddr: 100.64.0.2:...` confirms it
came through TB's Caddy over the mesh.
