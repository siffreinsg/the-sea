# Foundation Core Implementation Plan (Plan 1 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Reality check:** most steps here run on remote hosts (SSH) or in web dashboards (Cloudflare, Oracle, GitHub, Komodo UI). An agent can write the repo files and verify endpoints; the human runs the server-side and dashboard steps.

**Goal:** Mesh (Headscale) + ingress (Caddy) + secrets flow (SOPS) + GitOps deploy (Komodo) running end-to-end, proven by a canary stack deployed from Git to Going Merry and served at `https://whoami.siffreinsigy.me`.

**Architecture:** Thriller Bark hosts everything public (Caddy on host network, ports 80/443) and the control plane (Headscale, Komodo Core). Going Merry joins the mesh in userspace mode (old OpenVZ kernel) and runs a Periphery agent; all its services bind to 127.0.0.1 and are reached over the mesh. Backups = Plan 2, observability = Plan 3.

**Tech Stack:** Caddy 2 (+ caddy-dns/cloudflare), Headscale 0.26, Tailscale clients, Komodo Core + Periphery, MongoDB 7, SOPS + age.

## Global Constraints

- Domain: `siffreinsigy.me`, Cloudflare DNS-only (grey cloud), wildcard `*.siffreinsigy.me` → Thriller Bark public IP.
- Public ports 80/443 open **only** on Thriller Bark. Everything else binds `127.0.0.1` or a mesh address.
- age recipient: `age1wce7sqneyq58tux6fnpj2e2tsc05j4jqk8h8dguu0jc6eplfrslqqdw7md` (from `.sops.yaml`). Private key: password manager + `/etc/sops/age.key` on each node (root, mode 600).
- Encrypted secrets are committed as `secrets.env`; decrypted output is `.env` (gitignored). Decryption happens on the node at deploy time: `sops -d secrets.env > .env`.
- GitOps source: `git@github.com:siffreinsg/the-sea.git`, branch `main`.
- ACME e-mail: `siffr.hdesigy@gmail.com`.
- MagicDNS base domain: `mesh.siffreinsigy.me` (mesh hostnames: `thriller-bark.mesh.siffreinsigy.me`, `going-merry.mesh.siffreinsigy.me`).
- Image tags below were current at plan time — check for newer patch releases before deploying, don't chase majors mid-plan.

---

### Task 1: DNS + Cloudflare token + Caddy secrets

**Files:**
- Create: `thriller-bark/caddy/secrets.env` (sops-encrypted)

**Interfaces:**
- Produces: `CF_API_TOKEN` env var consumed by the Caddyfile in Task 3; DNS records every later `https://*.siffreinsigy.me` verify step depends on.

- [ ] **Step 1: Create the Cloudflare API token** — dashboard → My Profile → API Tokens → Create Token → template "Edit zone DNS", scope: zone `siffreinsigy.me` only. Copy the token.

- [ ] **Step 2: Create DNS records** — Cloudflare → siffreinsigy.me → DNS:
  - `A` record, name `*`, content = Thriller Bark public IP, **DNS only** (grey cloud).
  - `A` record, name `@`, same IP, DNS only.

- [ ] **Step 3: Verify DNS resolves**

```bash
dig +short canary.siffreinsigy.me
```
Expected: the Thriller Bark public IP.

- [ ] **Step 4: Write and encrypt the secret**

```bash
cd ~/projects/the-sea
mkdir -p thriller-bark/caddy
cat > thriller-bark/caddy/secrets.env <<'EOF'
CF_API_TOKEN=<paste token here>
EOF
sops -e -i thriller-bark/caddy/secrets.env
```

- [ ] **Step 5: Verify round-trip**

```bash
sops -d thriller-bark/caddy/secrets.env | grep -c CF_API_TOKEN
```
Expected: `1` (and `git diff` shows only ciphertext).

- [ ] **Step 6: Commit**

```bash
git add thriller-bark/caddy/secrets.env
git commit -m "feat(caddy): cloudflare token (sops)"
```

---

### Task 2: Thriller Bark base setup

**Files:** none in repo (server-side only).

**Interfaces:**
- Produces: a reachable Docker host with `sops`, `age`, `tailscale` installed, repo cloned at `/opt/the-sea`, age key at `/etc/sops/age.key`, ports 80/443 open. Every later TB task assumes this.

- [ ] **Step 1: Open ports in the OCI console** — instance → subnet → Security List → add ingress rules: TCP 80, TCP 443 from `0.0.0.0/0`. (Optional: UDP 41641 for direct Tailscale connections; DERP relay works without it.)

- [ ] **Step 2: Open the host firewall** (Oracle images ship restrictive iptables)

```bash
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

- [ ] **Step 3: Install Docker, sops, age, tailscale**

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
curl -fsSL https://tailscale.com/install.sh | sudo sh
sudo apt-get install -y age
SOPS_V=v3.9.4
sudo curl -fsSLo /usr/local/bin/sops \
  https://github.com/getsops/sops/releases/download/${SOPS_V}/sops-${SOPS_V}.linux.arm64
sudo chmod +x /usr/local/bin/sops
```

- [ ] **Step 4: Drop the age key** (paste from password manager)

```bash
sudo mkdir -p /etc/sops
sudo sh -c 'umask 077; cat > /etc/sops/age.key'   # paste key, Ctrl-D
```

- [ ] **Step 5: Clone the repo**

```bash
sudo git clone git@github.com:siffreinsg/the-sea.git /opt/the-sea
sudo chown -R $USER /opt/the-sea
```
(Needs a deploy key or your SSH agent forwarded; a read-only GitHub deploy key on this host is fine.)

- [ ] **Step 6: Verify**

```bash
docker run --rm hello-world && sops --version && age --version
export SOPS_AGE_KEY_FILE=/etc/sops/age.key
sops -d /opt/the-sea/thriller-bark/caddy/secrets.env | grep -c CF_API_TOKEN
```
Expected: hello-world banner, versions, `1`.

---

### Task 3: Caddy edge

**Files:**
- Create: `thriller-bark/caddy/Dockerfile`
- Create: `thriller-bark/caddy/compose.yaml`
- Create: `thriller-bark/caddy/Caddyfile`

**Interfaces:**
- Consumes: `secrets.env` from Task 1, host from Task 2.
- Produces: wildcard TLS on `*.siffreinsigy.me`; later tasks append `@name host …` handle blocks to this Caddyfile (Headscale in Task 4, Komodo in Task 6, whoami in Task 8).

- [ ] **Step 1: Write the files**

`thriller-bark/caddy/Dockerfile`:
```dockerfile
FROM caddy:2-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

`thriller-bark/caddy/compose.yaml`:
```yaml
services:
  caddy:
    build: .
    container_name: caddy
    network_mode: host          # binds 80/443; backends reached via 127.0.0.1 and mesh DNS
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config

volumes:
  caddy-data:
  caddy-config:
```

`thriller-bark/caddy/Caddyfile`:
```caddyfile
{
	email siffr.hdesigy@gmail.com
	acme_dns cloudflare {env.CF_API_TOKEN}
}

*.siffreinsigy.me {
	@up host up.siffreinsigy.me
	handle @up {
		respond "the sea is up" 200
	}

	handle {
		abort
	}
}
```

- [ ] **Step 2: Commit**

```bash
git add thriller-bark/caddy && git commit -m "feat(caddy): edge with cloudflare dns-01 wildcard" && git push
```

- [ ] **Step 3: Deploy on Thriller Bark**

```bash
cd /opt/the-sea && git pull
cd thriller-bark/caddy
export SOPS_AGE_KEY_FILE=/etc/sops/age.key
sops -d secrets.env > .env
docker compose up -d --build
```

- [ ] **Step 4: Verify TLS + routing**

```bash
curl -s https://up.siffreinsigy.me
```
Expected: `the sea is up` with no cert warning. If ACME fails, `docker logs caddy` — DNS-01 errors mean token scope or propagation.

---

### Task 4: Headscale

**Files:**
- Create: `thriller-bark/headscale/compose.yaml`
- Create: `thriller-bark/headscale/config.yaml`
- Modify: `thriller-bark/caddy/Caddyfile` (add handle block)

**Interfaces:**
- Consumes: Caddy from Task 3.
- Produces: `https://headscale.siffreinsigy.me` login server + one reusable preauth key per node, consumed by Task 5.

- [ ] **Step 1: Write the files**

`thriller-bark/headscale/compose.yaml`:
```yaml
services:
  headscale:
    image: headscale/headscale:0.26
    container_name: headscale
    command: serve
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - ./config.yaml:/etc/headscale/config.yaml:ro
      - headscale-data:/var/lib/headscale

volumes:
  headscale-data:
```

`thriller-bark/headscale/config.yaml`:
```yaml
server_url: https://headscale.siffreinsigy.me
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090

private_key_path: /var/lib/headscale/private.key
noise:
  private_key_path: /var/lib/headscale/noise_private.key

prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48

derp:
  urls:
    - https://controlplane.tailscale.com/derpmap/default

database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite

dns:
  magic_dns: true
  base_domain: mesh.siffreinsigy.me
  nameservers:
    global:
      - 1.1.1.1
```

Add inside the `*.siffreinsigy.me` block of `thriller-bark/caddy/Caddyfile`, above `handle {`:
```caddyfile
	@headscale host headscale.siffreinsigy.me
	handle @headscale {
		reverse_proxy 127.0.0.1:8080
	}
```

- [ ] **Step 2: Commit + deploy**

```bash
git add thriller-bark/headscale thriller-bark/caddy/Caddyfile
git commit -m "feat(headscale): control plane behind caddy" && git push
# on TB:
cd /opt/the-sea && git pull
docker compose -f thriller-bark/headscale/compose.yaml up -d
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

- [ ] **Step 3: Verify health**

```bash
curl -s https://headscale.siffreinsigy.me/health
```
Expected: `{"status":"pass"}`.

- [ ] **Step 4: Create user + preauth keys** (on TB)

```bash
docker exec headscale headscale users create sea
docker exec headscale headscale users list          # note the user id (likely 1)
docker exec headscale headscale preauthkeys create --user 1 --reusable --expiration 24h
```
Expected: a key string — save it for Task 5.

---

### Task 5: Join Thriller Bark + Going Merry to the mesh

**Files:** none in repo (server-side only; the GM systemd unit below is quoted in full here — that's its source of truth until a third node justifies a bootstrap script).

**Interfaces:**
- Consumes: preauth key from Task 4.
- Produces: mesh hostnames `thriller-bark.mesh.siffreinsigy.me` / `going-merry.mesh.siffreinsigy.me` used by Komodo (Task 7) and Caddy (Task 8).

- [ ] **Step 1: Join Thriller Bark** (kernel mode, package already installed in Task 2)

```bash
sudo tailscale up --login-server=https://headscale.siffreinsigy.me --auth-key=<KEY> --hostname=thriller-bark
```

- [ ] **Step 2: Install Tailscale on Going Merry** (static binary, userspace — old OpenVZ kernel)

```bash
curl -fsSL https://pkgs.tailscale.com/stable/tailscale_latest_amd64.tgz | sudo tar -xz -C /tmp
sudo install /tmp/tailscale_*/tailscale /tmp/tailscale_*/tailscaled /usr/local/bin/
sudo mkdir -p /var/lib/tailscale /run/tailscale
sudo tee /etc/systemd/system/tailscaled.service > /dev/null <<'EOF'
[Unit]
Description=Tailscale (userspace networking)
After=network.target

[Service]
ExecStart=/usr/local/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --tun=userspace-networking
Restart=on-failure
RuntimeDirectory=tailscale

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now tailscaled
sudo tailscale up --login-server=https://headscale.siffreinsigy.me --auth-key=<KEY> --hostname=going-merry
```

- [ ] **Step 3: Verify from Thriller Bark**

```bash
tailscale status
tailscale ping going-merry
ping -c1 going-merry.mesh.siffreinsigy.me
```
Expected: both nodes listed, ping succeeds, MagicDNS resolves to a `100.64.x.x` address.

> Userspace-mode caveat on GM: **inbound** mesh connections are forwarded to `127.0.0.1:<same port>` (all we need — Core and Caddy dial in). **Outbound** to the mesh from GM apps doesn't work without a SOCKS proxy; nothing in this plan needs it (revisit in Plan 3 for Alloy).

---

### Task 6: Komodo Core

**Files:**
- Create: `thriller-bark/komodo/compose.yaml`
- Create: `thriller-bark/komodo/secrets.env` (sops-encrypted)
- Modify: `thriller-bark/caddy/Caddyfile` (add handle block)

**Interfaces:**
- Consumes: mesh from Task 5 (host networking so Core can dial GM's mesh address).
- Produces: `https://komodo.siffreinsigy.me` UI; `KOMODO_PASSKEY` value shared with the Periphery configs in Task 7.

- [ ] **Step 1: Generate secrets and encrypt**

```bash
cd ~/projects/the-sea && mkdir -p thriller-bark/komodo
cat > thriller-bark/komodo/secrets.env <<EOF
KOMODO_DB_PASSWORD=$(openssl rand -hex 16)
KOMODO_PASSKEY=$(openssl rand -hex 32)
KOMODO_JWT_SECRET=$(openssl rand -hex 32)
KOMODO_WEBHOOK_SECRET=$(openssl rand -hex 32)
EOF
sops -e -i thriller-bark/komodo/secrets.env
```
(Note `KOMODO_PASSKEY` in your password manager too — Task 7 pastes it on both nodes.)

- [ ] **Step 2: Write the compose file**

`thriller-bark/komodo/compose.yaml`:
```yaml
services:
  mongo:
    image: mongo:7
    container_name: komodo-mongo
    restart: unless-stopped
    command: --quiet --wiredTigerCacheSizeGB 0.25
    ports:
      - "127.0.0.1:27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: komodo
      MONGO_INITDB_ROOT_PASSWORD: ${KOMODO_DB_PASSWORD}
    volumes:
      - mongo-data:/data/db

  core:
    image: ghcr.io/moghtech/komodo-core:latest
    container_name: komodo-core
    network_mode: host          # must reach periphery agents over the mesh
    restart: unless-stopped
    depends_on: [mongo]
    env_file: .env
    environment:
      KOMODO_HOST: https://komodo.siffreinsigy.me
      KOMODO_TITLE: The Sea
      KOMODO_DATABASE_ADDRESS: 127.0.0.1:27017
      KOMODO_DATABASE_USERNAME: komodo
      KOMODO_DATABASE_PASSWORD: ${KOMODO_DB_PASSWORD}
      KOMODO_PASSKEY: ${KOMODO_PASSKEY}
      KOMODO_JWT_SECRET: ${KOMODO_JWT_SECRET}
      KOMODO_WEBHOOK_SECRET: ${KOMODO_WEBHOOK_SECRET}
      KOMODO_LOCAL_AUTH: "true"
      KOMODO_DISABLE_USER_REGISTRATION: "false"   # flip to true after first login

volumes:
  mongo-data:
```

Add to the Caddyfile (inside `*.siffreinsigy.me`, above `handle {`; Core listens on 9120):
```caddyfile
	@komodo host komodo.siffreinsigy.me
	handle @komodo {
		reverse_proxy 127.0.0.1:9120
	}
```

- [ ] **Step 3: Commit + deploy**

```bash
git add thriller-bark/komodo thriller-bark/caddy/Caddyfile
git commit -m "feat(komodo): core + mongo behind caddy" && git push
# on TB:
cd /opt/the-sea && git pull && cd thriller-bark/komodo
sops -d secrets.env > .env
docker compose up -d
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

- [ ] **Step 4: Verify** — open `https://komodo.siffreinsigy.me`, create the admin user, log in. Then set `KOMODO_DISABLE_USER_REGISTRATION: "true"`, commit, redeploy.

---

### Task 7: Periphery agents on both Docker nodes

**Files:** none in repo (host config `/etc/komodo/periphery.config.toml` on each node).

**Interfaces:**
- Consumes: `KOMODO_PASSKEY` from Task 6, mesh from Task 5.
- Produces: servers `thriller-bark` + `going-merry` connectable by Core — referenced by name in `komodo/resources.toml` (Task 8).

- [ ] **Step 1: Install Periphery on Thriller Bark** (systemd binary, not container — it must run `sops` for pre-deploy hooks)

```bash
curl -fsSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py | sudo python3
sudo tee /etc/komodo/periphery.config.toml > /dev/null <<'EOF'
port = 8120
bind_ip = "127.0.0.1"
passkeys = ["<KOMODO_PASSKEY>"]
repo_dir = "/opt/komodo/repos"
stack_dir = "/opt/komodo/stacks"
EOF
sudo mkdir -p /etc/systemd/system/periphery.service.d
sudo tee /etc/systemd/system/periphery.service.d/sops.conf > /dev/null <<'EOF'
[Service]
Environment=SOPS_AGE_KEY_FILE=/etc/sops/age.key
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now periphery
```

- [ ] **Step 2: Install on Going Merry** — same commands, **plus** sops/age/key first (GM is amd64):

```bash
sudo apt-get install -y age
SOPS_V=v3.9.4
sudo curl -fsSLo /usr/local/bin/sops \
  https://github.com/getsops/sops/releases/download/${SOPS_V}/sops-${SOPS_V}.linux.amd64
sudo chmod +x /usr/local/bin/sops
sudo mkdir -p /etc/sops
sudo sh -c 'umask 077; cat > /etc/sops/age.key'   # paste key, Ctrl-D
```
Then repeat the Step 1 block verbatim. `bind_ip = "127.0.0.1"` matters here: userspace Tailscale forwards inbound mesh traffic to localhost, and nothing gets exposed on GM's public IP.

- [ ] **Step 3: Verify agents answer locally** (on each node)

```bash
curl -sk https://127.0.0.1:8120/health
```
Expected: HTTP 200 (or 401 without passkey — either proves it's listening).

- [ ] **Step 4: Verify GM is reachable over the mesh** (from TB)

```bash
curl -sk https://going-merry.mesh.siffreinsigy.me:8120/health
```
Expected: same response as locally.

---

### Task 8: GitOps resource sync + canary stack (proves the whole chain)

**Files:**
- Create: `komodo/resources.toml`
- Create: `going-merry/whoami/compose.yaml`
- Create: `going-merry/whoami/secrets.env` (sops-encrypted)
- Modify: `thriller-bark/caddy/Caddyfile` (add handle block)

**Interfaces:**
- Consumes: servers from Task 7.
- Produces: the repeatable add-a-service pattern (documented in Task 9): compose + secrets.env in a ship dir, `[[stack]]` entry in `komodo/resources.toml`, handle block in the Caddyfile.

- [ ] **Step 1: Connect the repo to Komodo** — GitHub → Settings → Developer settings → Fine-grained token, read-only **Contents** on `siffreinsg/the-sea`. In Komodo UI: **Settings → Git Accounts → Add**: provider `github.com`, account `siffreinsg`, the token.

- [ ] **Step 2: Write the canary stack**

`going-merry/whoami/compose.yaml`:
```yaml
services:
  whoami:
    image: traefik/whoami
    container_name: whoami
    restart: unless-stopped
    env_file: .env
    ports:
      - "127.0.0.1:8090:80"
```

```bash
mkdir -p going-merry/whoami
cat > going-merry/whoami/secrets.env <<'EOF'
WHOAMI_NAME=sops-decryption-works
EOF
sops -e -i going-merry/whoami/secrets.env
```

- [ ] **Step 3: Write the resource sync**

`komodo/resources.toml`:
```toml
[[server]]
name = "thriller-bark"
[server.config]
address = "https://127.0.0.1:8120"
enabled = true

[[server]]
name = "going-merry"
[server.config]
address = "https://going-merry.mesh.siffreinsigy.me:8120"
enabled = true

[[stack]]
name = "whoami"
[stack.config]
server = "going-merry"
git_account = "siffreinsg"
repo = "siffreinsg/the-sea"
branch = "main"
run_directory = "going-merry/whoami"
pre_deploy.command = "sops -d secrets.env > .env"
```

Caddyfile block (inside `*.siffreinsigy.me`, above `handle {`):
```caddyfile
	@whoami host whoami.siffreinsigy.me
	handle @whoami {
		reverse_proxy going-merry.mesh.siffreinsigy.me:8090
	}
```

- [ ] **Step 4: Commit + create the sync**

```bash
git add komodo going-merry/whoami thriller-bark/caddy/Caddyfile
git commit -m "feat(komodo): resource sync + whoami canary on going-merry" && git push
```
Komodo UI → **Syncs → New**: name `the-sea`, git account `siffreinsg`, repo `siffreinsg/the-sea`, branch `main`, resource path `komodo`. Execute Sync → both servers appear green, stack `whoami` appears. Deploy the stack. Reload Caddy on TB:
```bash
cd /opt/the-sea && git pull && docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

- [ ] **Step 5: Verify the entire chain**

```bash
curl -s https://whoami.siffreinsigy.me | grep Name
```
Expected: `Name: sops-decryption-works` — Git → sync → Core → mesh → Periphery → sops decrypt → container → Caddy → TLS, all in one line.

- [ ] **Step 6: Enable webhook (optional but cheap)** — Komodo sync page shows a webhook URL; add it to the GitHub repo (Settings → Webhooks, secret = `KOMODO_WEBHOOK_SECRET`) so pushes trigger syncs. Skip if manual "Execute Sync" is fine for now.

---

### Task 9: Add-a-service runbook

**Files:**
- Create: `docs/runbooks/add-a-service.md`

**Interfaces:**
- Consumes: the pattern proven in Task 8.

- [ ] **Step 1: Write the runbook**

`docs/runbooks/add-a-service.md`:
```markdown
# Add a service

1. `mkdir <ship>/<app>` → `compose.yaml`. Bind ports to `127.0.0.1`; unique port per app on that ship.
2. Secrets: `cat > <ship>/<app>/secrets.env` → `sops -e -i <ship>/<app>/secrets.env`.
   Compose references them via `env_file: .env`.
3. Append to `komodo/resources.toml`:

       [[stack]]
       name = "<app>"
       [stack.config]
       server = "<ship>"
       git_account = "siffreinsg"
       repo = "siffreinsg/the-sea"
       branch = "main"
       run_directory = "<ship>/<app>"
       pre_deploy.command = "sops -d secrets.env > .env"

4. Public? Append to `thriller-bark/caddy/Caddyfile` inside the wildcard block:

       @<app> host <app>.siffreinsigy.me
       handle @<app> {
           reverse_proxy <target>:<port>   # 127.0.0.1 on TB, <ship>.mesh.siffreinsigy.me otherwise
       }

5. Push → Execute Sync (or webhook) → Deploy in Komodo → reload Caddy if step 4:
   `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`
```

- [ ] **Step 2: Commit**

```bash
git add docs/runbooks/add-a-service.md
git commit -m "docs: add-a-service runbook" && git push
```

---

## Self-review notes

- Spec coverage: mesh ✔ (T4–5), ingress ✔ (T3), secrets ✔ (T1, pre-deploy hook T7–8), deploy ✔ (T6–8). Backups + observability intentionally out (Plans 2–3). Sunny/Den Den Mushi join the mesh in later plans when something needs them.
- Caddy and Komodo Core run with host networking so they can dial mesh addresses; every backend binds 127.0.0.1 — this pairing is deliberate, don't "fix" it to bridge networks.
- Komodo CLI flags / config keys (`preauthkeys --user <id>`, `pre_deploy.command`, `KOMODO_*` env names) move between releases — if a step errors, check `--help`/current docs before assuming the plan is wrong elsewhere.
