# Add a service

The repeatable pattern, proven by the whoami canary (T8). Every new service is
four things: a **ship dir** (compose + secrets), a **stack entry**, a **Caddy
handle block**, and one **sync + deploy**. No per-service DNS — the wildcard
`*.siffreinsigy.me` already resolves to Thriller Bark.

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

## 4. Ship it

```bash
git add <node>/<app> komodo/resources.toml thriller-bark/caddy/Caddyfile
git commit -m "feat(<app>): deploy on <node>" && git push
```
Then:
- **Komodo:** Execute the `the-sea` Sync (or let the GitHub webhook fire it) → the new
  stack appears → **Deploy** it. Watch the deploy log; the `pre_deploy` sops step is
  where a missing/rotated key shows up.
- **Caddy (TB)** — Komodo Sync deploys `caddy-tb` automatically (`extra_args =
  ["--force-recreate", "--build"]` avoids the stale-inode issue from `git pull`
  swapping the Caddyfile — never `caddy reload`).

## 5. Verify

```bash
curl -s https://<app>.siffreinsigy.me
```
For a GM app, a successful response with `RemoteAddr: 100.64.0.2:...` confirms it
came through TB's Caddy over the mesh.
