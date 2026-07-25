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
pre_deploy.command = "sops -d secrets.env > .env"   # omit if no secrets.env
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
# secret + its hash: Authelia's own CLI, in the running container
docker exec authelia authelia crypto hash generate pbkdf2 --variant sha512 --password '<secret>'
# adding a whole client: open the file, append to the clients array
sops thriller-bark/authelia/secrets.oidc.yml
```
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

## 3c. Backups — mandatory if stateful

- **Live DB** → drop a `backup.sh` in the service dir writing to
  `/var/backups/the-sea/dumps/` (pattern: `going-merry/dawarich/backup.sh` — atomic
  `.part` + `mv`, dump inside the container). The node's `run.sh` globs it up
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
