# Infrastructure Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Note:** This is an infrastructure runbook. Most steps run against live remote
> hosts and external accounts (Cloudflare, Proton, Mega, Oracle). "Verify" steps
> replace unit tests. Steps that require credentials or console access are marked
> **[OPERATOR]** — a human must run them; they can't be automated from this repo.

**Goal:** Stand up the cross-cutting foundation — Tailscale mesh, SOPS secrets, Komodo GitOps, Caddy edge, Backrest backups, and the observability stack — proven end-to-end by migrating one pilot service (dawarich) from the old repo.

**Architecture:** Four nodes on a Tailscale tailnet. Thriller Bark (Oracle) is the control plane running Komodo Core, Caddy, Backrest, and Grafana/VictoriaMetrics/Loki. Docker stacks deploy from this Git repo via Komodo Resource Sync. Secrets are SOPS+age encrypted in-repo. Backups go restic→rclone→Proton (all) + Mega (critical subset).

**Tech Stack:** Docker + Docker Compose, Tailscale, Komodo, Caddy (with Cloudflare DNS plugin), SOPS + age, restic + rclone + Backrest, Grafana + VictoriaMetrics + Loki + Grafana Alloy.

## Global Constraints

- **No HA / no Kubernetes.** Compose only. Do not introduce an orchestrator.
- **Cloudflare is DNS-only** (grey cloud). Never enable the orange-cloud proxy for these records.
- **No plaintext secrets committed.** Every `*.env` / `secrets.*` file must be SOPS-encrypted before `git add`. Verify with `git diff --cached` showing ciphertext.
- **Public ports (80/443) open only on Thriller Bark.** All other node-to-node traffic rides the tailnet.
- **The Thousand Sunny (Ultra.cc) and Den Den Mushi (Pi) are out of scope** for this foundation except joining the tailnet — no Docker/Komodo there.
- **Userspace Tailscale** (`--tun=userspace-networking`) on Going Merry and Sunny (no root / no `/dev/net/tun`).
- **Timezone `Europe/Paris`**, domain root `<DOMAIN>` (e.g. `siffreinsigy.me`).

---

## Task 1: Repo scaffolding + `.gitignore` + `.sops.yaml`

**Files:**
- Create: `.gitignore`, `.sops.yaml`
- Create: `komodo/.gitkeep`, `scripts/.gitkeep`, `thriller-bark/.gitkeep`, `dendenmushi/.gitkeep`, `docs/runbooks/.gitkeep`

**Interfaces:**
- Produces: repo directory skeleton matching the spec §5 layout; `.sops.yaml` rule that encrypts `**/*.env` and `**/secrets.*` for age recipient `<AGE_PUBLIC_KEY>`.

- [ ] **Step 1: Create the age keypair [OPERATOR]**

```bash
# Local workstation. This key is the ONE out-of-band secret for the whole infra.
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
grep 'public key' ~/.config/sops/age/keys.txt   # copy the age1... value
```

Store `keys.txt` (private) in your password manager. Do NOT commit it.

- [ ] **Step 2: Write `.gitignore`**

```gitignore
# Decrypted secrets never get committed
*.dec
*.env.plain
# age private keys
keys.txt
*.age.key
# runtime data / volumes
**/data/
**/*_data/
**/letsencrypt/
# OS noise
.DS_Store
```

- [ ] **Step 3: Write `.sops.yaml`** (replace `<AGE_PUBLIC_KEY>`)

```yaml
creation_rules:
  - path_regex: (.*\.env|.*/secrets\..*)$
    age: <AGE_PUBLIC_KEY>
```

- [ ] **Step 4: Create dir skeleton**

```bash
mkdir -p komodo scripts thriller-bark dendenmushi docs/runbooks
touch komodo/.gitkeep scripts/.gitkeep thriller-bark/.gitkeep dendenmushi/.gitkeep docs/runbooks/.gitkeep
```

- [ ] **Step 5: Verify SOPS round-trips**

```bash
echo 'FOO=bar' > test.env
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops -e -i test.env
grep -q 'ENC\[' test.env && echo "ENCRYPTED OK"     # expect: ENCRYPTED OK
git add -n test.env                                  # dry-run; confirm it'd be tracked as ciphertext
rm test.env
```

Expected: prints `ENCRYPTED OK` and the file shows `ENC[...]` blocks, no plaintext `bar`.

- [ ] **Step 6: Commit**

```bash
git add .gitignore .sops.yaml komodo scripts thriller-bark dendenmushi docs
git commit -m "chore: repo scaffolding, gitignore, sops config"
```

---

## Task 2: Tailscale mesh across all four nodes

**Files:**
- Create: `scripts/bootstrap-tailscale.sh`
- Create: `docs/runbooks/add-a-node.md`

**Interfaces:**
- Produces: all four nodes on one tailnet, MagicDNS names reachable. Node names: `thriller-bark`, `going-merry`, `thethousandsunny`, `dendenmushi`.

- [ ] **Step 1: Create tailnet + auth key [OPERATOR]**

In the Tailscale admin console: enable **MagicDNS**, create a reusable **auth key** (`<TS_AUTHKEY>`), tag it `tag:server`.

- [ ] **Step 2: Write `scripts/bootstrap-tailscale.sh`**

```bash
#!/usr/bin/env bash
# Usage: bootstrap-tailscale.sh <hostname> [--userspace]
# Installs tailscale and joins the tailnet. --userspace for no-root / OpenVZ / Ultra.cc.
set -euo pipefail
HOSTNAME="${1:?need hostname}"; MODE="${2:-}"
: "${TS_AUTHKEY:?export TS_AUTHKEY first}"

if [[ "$MODE" == "--userspace" ]]; then
  # No root: download static binary into ~/.local, run tailscaled in userspace.
  mkdir -p "$HOME/.local/bin" "$HOME/.local/tailscale"
  curl -fsSL https://pkgs.tailscale.com/stable/tailscale_latest_$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').tgz \
    | tar -xz --strip-components=1 -C "$HOME/.local/tailscale"
  ln -sf "$HOME/.local/tailscale/tailscale" "$HOME/.local/bin/tailscale"
  "$HOME/.local/tailscale/tailscaled" --tun=userspace-networking \
    --statedir="$HOME/.local/tailscale/state" --socket="$HOME/.local/tailscale/ts.sock" &
  sleep 3
  "$HOME/.local/bin/tailscale" --socket="$HOME/.local/tailscale/ts.sock" \
    up --authkey="$TS_AUTHKEY" --hostname="$HOSTNAME" --ssh
else
  curl -fsSL https://tailscale.com/install.sh | sh
  sudo tailscale up --authkey="$TS_AUTHKEY" --hostname="$HOSTNAME" --ssh
fi
```

- [ ] **Step 3: Join Thriller Bark (root) [OPERATOR]**

```bash
# On Thriller Bark. Oracle images also need the host firewall opened later (Task 6).
TS_AUTHKEY=<TS_AUTHKEY> bash scripts/bootstrap-tailscale.sh thriller-bark
```

- [ ] **Step 4: Join Going Merry (userspace) [OPERATOR]**

```bash
# On Going Merry (OpenVZ). Userspace avoids the /dev/net/tun requirement.
TS_AUTHKEY=<TS_AUTHKEY> bash scripts/bootstrap-tailscale.sh going-merry --userspace
```

- [ ] **Step 5: Join The Thousand Sunny (userspace) [OPERATOR]**

```bash
# On Ultra.cc via SSH, no sudo.
TS_AUTHKEY=<TS_AUTHKEY> bash scripts/bootstrap-tailscale.sh thethousandsunny --userspace
```

- [ ] **Step 6: Join Den Den Mushi [OPERATOR]**

In Home Assistant: install the **Tailscale add-on**, set hostname `dendenmushi`, start it, authenticate with `<TS_AUTHKEY>`.

- [ ] **Step 7: Verify the mesh**

```bash
# From Thriller Bark:
tailscale status                         # expect all 4 nodes listed, state "active"/"idle"
tailscale ping going-merry               # expect a reply (direct or via DERP)
ping -c1 thethousandsunny                # MagicDNS name resolves
```

Expected: all four hostnames appear; pings succeed.

- [ ] **Step 8: Document + commit**

Write `docs/runbooks/add-a-node.md` (copy the steps above as a reusable procedure), then:

```bash
git add scripts/bootstrap-tailscale.sh docs/runbooks/add-a-node.md
git commit -m "feat: tailscale mesh bootstrap + add-a-node runbook"
```

---

## Task 3: Docker + Komodo Core on Thriller Bark

**Files:**
- Create: `thriller-bark/komodo/compose.yaml`
- Create: `thriller-bark/komodo/secrets.env` (SOPS-encrypted)

**Interfaces:**
- Consumes: tailnet (Task 2).
- Produces: Komodo Core web UI on `http://thriller-bark:9120` (tailnet-only); a `KOMODO_PASSKEY` shared with agents in Task 4.

- [ ] **Step 1: Ensure Docker present on Thriller Bark [OPERATOR]**

```bash
# On Thriller Bark (Ubuntu/Oracle Linux ARM):
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"   # re-login after
docker run --rm hello-world       # expect "Hello from Docker!"
```

- [ ] **Step 2: Write `thriller-bark/komodo/compose.yaml`**

Based on the official Komodo Postgres+FerretDB compose. Bind the UI to the tailnet interface only.

```yaml
services:
  komodo-core:
    image: ghcr.io/moghtech/komodo-core:latest
    container_name: komodo-core
    restart: unless-stopped
    depends_on: [komodo-db]
    ports:
      - "127.0.0.1:9120:9120"   # reach via tailnet through Caddy/SSH; not public
    env_file: secrets.env
    environment:
      KOMODO_HOST: https://komodo.<DOMAIN>
      KOMODO_DATABASE_ADDRESS: komodo-db:27017
      KOMODO_PASSKEY: ${KOMODO_PASSKEY}
      KOMODO_WEBHOOK_SECRET: ${KOMODO_WEBHOOK_SECRET}
      KOMODO_JWT_SECRET: ${KOMODO_JWT_SECRET}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
  komodo-db:
    image: ghcr.io/ferretdb/ferretdb:latest
    container_name: komodo-db
    restart: unless-stopped
    volumes:
      - ./db_data:/state
    environment:
      FERRETDB_POSTGRESQL_URL: postgres://komodo:${DB_PASSWORD}@komodo-pg:5432/komodo
    depends_on: [komodo-pg]
  komodo-pg:
    image: postgres:17-alpine
    container_name: komodo-pg
    restart: unless-stopped
    environment:
      POSTGRES_USER: komodo
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: komodo
    volumes:
      - ./pg_data:/var/lib/postgresql/data
```

- [ ] **Step 3: Create + encrypt secrets**

```bash
cd thriller-bark/komodo
cat > secrets.env <<EOF
KOMODO_PASSKEY=$(openssl rand -hex 32)
KOMODO_WEBHOOK_SECRET=$(openssl rand -hex 32)
KOMODO_JWT_SECRET=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 24)
EOF
sops -e -i secrets.env
grep -q 'ENC\[' secrets.env && echo "ENCRYPTED OK"   # expect ENCRYPTED OK
```

- [ ] **Step 4: Deploy [OPERATOR]**

```bash
# On Thriller Bark, with the age key available:
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops -d secrets.env > .env       # decrypt for compose; .env is gitignored
docker compose up -d
```

- [ ] **Step 5: Verify Komodo Core is up**

```bash
curl -fsS http://localhost:9120/ | grep -qi komodo && echo "KOMODO UP"   # expect KOMODO UP
# From your workstation over the tailnet:
curl -fsS http://thriller-bark:9120/ >/dev/null && echo "REACHABLE VIA TAILNET"
```

- [ ] **Step 6: Create first admin user [OPERATOR]**

Open `http://thriller-bark:9120` over the tailnet, register the admin account, then disable open registration in Komodo settings.

- [ ] **Step 7: Commit** (ciphertext only)

```bash
git add thriller-bark/komodo/compose.yaml thriller-bark/komodo/secrets.env
git commit -m "feat: komodo core stack on thriller-bark"
```

---

## Task 4: Komodo Periphery agents on Thriller Bark + Going Merry

**Files:**
- Create: `scripts/install-komodo-periphery.sh`

**Interfaces:**
- Consumes: `KOMODO_PASSKEY` (Task 3).
- Produces: two registered Komodo Servers, `thriller-bark` and `going-merry`, both "Ok" in the UI.

- [ ] **Step 1: Write `scripts/install-komodo-periphery.sh`**

```bash
#!/usr/bin/env bash
# Installs the Komodo periphery agent as a systemd service, bound to tailnet.
set -euo pipefail
: "${KOMODO_PASSKEY:?export KOMODO_PASSKEY}"
curl -fsSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py | python3 - \
  --passkeys "$KOMODO_PASSKEY"
# Bind periphery to the tailscale IP only (edit /etc/komodo/periphery.config.toml: bind_ip = "<tailscale-ip>")
```

- [ ] **Step 2: Install on Thriller Bark [OPERATOR]**

```bash
KOMODO_PASSKEY=<from-secrets> bash scripts/install-komodo-periphery.sh
systemctl status periphery   # expect active (running)
```

- [ ] **Step 3: Install on Going Merry [OPERATOR]**

```bash
# Going Merry runs Docker already; install periphery the same way.
KOMODO_PASSKEY=<from-secrets> bash scripts/install-komodo-periphery.sh
```

- [ ] **Step 4: Register both servers in Komodo UI [OPERATOR]**

In Komodo → Servers → Add: address `http://thriller-bark:8120` and `http://going-merry:8120` (tailnet names), paste the passkey.

- [ ] **Step 5: Verify**

Both servers show **State: Ok** with live CPU/mem stats in the Komodo UI.

- [ ] **Step 6: Commit**

```bash
git add scripts/install-komodo-periphery.sh
git commit -m "feat: komodo periphery installer"
```

---

## Task 5: Komodo Resource Sync wired to this repo

**Files:**
- Create: `komodo/servers.toml`
- Create: `komodo/resource-sync.toml`

**Interfaces:**
- Consumes: registered servers (Task 4).
- Produces: a Komodo Resource Sync that reads `komodo/*.toml` from this repo's git remote and reconciles Stacks onto servers. Later tasks add Stack entries here.

- [ ] **Step 1: Connect the git repo in Komodo [OPERATOR]**

Komodo → Settings → Git Providers: add `github.com/siffreinsg/the-sea` with a read token (`<GIT_TOKEN>`), or make it a public repo (no secrets are plaintext, so public is safe).

- [ ] **Step 2: Write `komodo/servers.toml`**

```toml
[[server]]
name = "thriller-bark"
address = "http://thriller-bark:8120"
enabled = true

[[server]]
name = "going-merry"
address = "http://going-merry:8120"
enabled = true
```

- [ ] **Step 3: Write `komodo/resource-sync.toml`** (Stacks list grows in later tasks)

```toml
[[resource_sync]]
name = "the-sea"
[resource_sync.config]
repo = "siffreinsg/the-sea"
branch = "main"
resource_path = ["komodo"]
managed = true
```

- [ ] **Step 4: Create the Resource Sync in Komodo pointing at `komodo/` [OPERATOR]**

Komodo → Syncs → New → repo `the-sea`, path `komodo`. Run **Preview**.

- [ ] **Step 5: Verify**

Preview shows the two servers as "to create/update" and **no errors**. Execute the sync; both servers reconcile.

- [ ] **Step 6: Commit**

```bash
git add komodo/servers.toml komodo/resource-sync.toml
git commit -m "feat: komodo resource sync from repo"
```

---

## Task 6: Caddy edge on Thriller Bark (Cloudflare DNS-01)

**Files:**
- Create: `thriller-bark/caddy/compose.yaml`
- Create: `thriller-bark/caddy/Caddyfile`
- Create: `thriller-bark/caddy/secrets.env` (SOPS-encrypted)
- Modify: `komodo/resource-sync.toml` (add caddy stack)

**Interfaces:**
- Consumes: tailnet + a Docker node.
- Produces: public HTTPS edge; wildcard cert for `*.<DOMAIN>`; reverse-proxy entries reachable at `https://<svc>.<DOMAIN>`.

- [ ] **Step 1: Create Cloudflare API token [OPERATOR]**

Cloudflare dashboard → API Tokens → create a token scoped to **Zone:DNS:Edit** for `<DOMAIN>` only. Save as `<CF_API_TOKEN>`.

- [ ] **Step 2: Open ports 80/443 on Thriller Bark [OPERATOR]**

```bash
# Oracle: add ingress rules for TCP 80,443 in the VCN Security List AND the host:
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

- [ ] **Step 3: Write `thriller-bark/caddy/compose.yaml`** (Caddy image built with the Cloudflare DNS plugin)

```yaml
services:
  caddy:
    image: ghcr.io/caddybuilds/caddy-cloudflare:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    env_file: secrets.env
    environment:
      CLOUDFLARE_API_TOKEN: ${CLOUDFLARE_API_TOKEN}
      ACME_EMAIL: <ACME_EMAIL>
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./data:/data
      - ./config:/config
```

- [ ] **Step 4: Write `thriller-bark/caddy/Caddyfile`** (wildcard cert; proxy to backends over tailnet)

```caddyfile
{
	email {env.ACME_EMAIL}
}

*.<DOMAIN> {
	tls {
		dns cloudflare {env.CLOUDFLARE_API_TOKEN}
	}

	@dawarich host dawarich.<DOMAIN>
	handle @dawarich {
		reverse_proxy going-merry:3000
	}

	@komodo host komodo.<DOMAIN>
	handle @komodo {
		reverse_proxy thriller-bark:9120
	}

	handle {
		respond "Not found" 404
	}
}
```

- [ ] **Step 5: Encrypt secrets**

```bash
cd thriller-bark/caddy
echo "CLOUDFLARE_API_TOKEN=<CF_API_TOKEN>" > secrets.env
sops -e -i secrets.env && grep -q 'ENC\[' secrets.env && echo "ENCRYPTED OK"
```

- [ ] **Step 6: Add DNS records [OPERATOR]**

In Cloudflare DNS (grey cloud / DNS-only): `A *.<DOMAIN> → <thriller-bark-public-ip>` (or per-host A records for `dawarich`, `komodo`).

- [ ] **Step 7: Deploy + verify TLS**

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops -d secrets.env > .env && docker compose up -d
sleep 30
curl -fsS -o /dev/null -w "%{http_code} %{ssl_verify_result}\n" https://komodo.<DOMAIN>
# expect: 200 0   (0 = cert verified). Confirm cert issuer is Let's Encrypt:
echo | openssl s_client -connect komodo.<DOMAIN>:443 2>/dev/null | grep -i "issuer"
```

Expected: HTTP 200, verified TLS, Let's Encrypt issuer.

- [ ] **Step 8: Add caddy stack to resource sync + commit**

Append to `komodo/resource-sync.toml`:

```toml
[[stack]]
name = "caddy"
[stack.config]
server = "thriller-bark"
run_directory = "thriller-bark/caddy"
file_paths = ["compose.yaml"]
```

```bash
git add thriller-bark/caddy komodo/resource-sync.toml
git commit -m "feat: caddy edge with cloudflare dns-01 wildcard certs"
```

---

## Task 7: Pilot service — migrate dawarich to Going Merry via Komodo

**Files:**
- Create: `going-merry/dawarich/compose.yaml` (adapted from old repo)
- Create: `going-merry/dawarich/secrets.env` (SOPS-encrypted)
- Modify: `komodo/resource-sync.toml`

**Interfaces:**
- Consumes: Caddy (Task 6), Komodo sync (Task 5).
- Produces: dawarich deployed by Komodo, served at `https://dawarich.<DOMAIN>`, its data ready for Task 8 backup.

- [ ] **Step 1: Copy + adapt the compose** — remove the external `revproxy` network (Caddy replaces it); keep the app on port 3000 for Caddy to reach over the tailnet.

Copy `going-merry/dawarich/compose.yaml` from the old repo, then delete the `revproxy` network block and the `networks: [default, revproxy]` line on `dawarich_app` (leave `default`). Confirm `dawarich_app` still publishes/exposes `3000`.

- [ ] **Step 2: Encrypt its secrets**

```bash
cd going-merry/dawarich
cat > secrets.env <<EOF
POSTGRES_PASSWORD=$(openssl rand -hex 24)
SECRET_KEY_BASE=$(openssl rand -hex 64)
EOF
sops -e -i secrets.env && grep -q 'ENC\[' secrets.env && echo "ENCRYPTED OK"
```

- [ ] **Step 3: Add the stack to `komodo/resource-sync.toml`**

```toml
[[stack]]
name = "dawarich"
[stack.config]
server = "going-merry"
run_directory = "going-merry/dawarich"
file_paths = ["compose.yaml"]
```

- [ ] **Step 4: Push + deploy from Komodo [OPERATOR]**

```bash
git add going-merry/dawarich komodo/resource-sync.toml
git commit -m "feat: pilot dawarich stack on going-merry via komodo"
git push
```

Then in Komodo: run the Sync (picks up the new stack), then **Deploy** the `dawarich` stack. Confirm Komodo decrypts secrets (configure the sops age key on the periphery host, or a Komodo pre-deploy action `sops -d secrets.env > .env`).

- [ ] **Step 5: Verify end-to-end**

```bash
curl -fsS -o /dev/null -w "%{http_code}\n" https://dawarich.<DOMAIN>/api/v1/health   # expect 200
```

Expected: 200 from the health endpoint, served through Caddy, deployed by Komodo, secrets from SOPS. **This proves the whole foundation path.**

---

## Task 8: Backrest backups → Proton (all) + Mega (critical)

**Files:**
- Create: `thriller-bark/backrest/compose.yaml`
- Create: `thriller-bark/backrest/secrets.env` (SOPS-encrypted)
- Create: `docs/runbooks/restore-test.md`
- Modify: `komodo/resource-sync.toml`

**Interfaces:**
- Consumes: dawarich data volumes (Task 7).
- Produces: two restic repos (`protondrive:the-sea`, `mega:the-sea-critical`) with scheduled backups + a verified restore.

- [ ] **Step 1: Configure rclone remotes [OPERATOR]**

```bash
# On Thriller Bark:
rclone config   # create remote "protondrive" (type: protondrive) and "mega" (type: mega)
rclone lsd protondrive: && rclone lsd mega:   # expect no error
```

- [ ] **Step 2: Write `thriller-bark/backrest/compose.yaml`**

```yaml
services:
  backrest:
    image: garethgeorge/backrest:latest
    container_name: backrest
    restart: unless-stopped
    ports:
      - "127.0.0.1:9898:9898"   # tailnet/SSH only; front via Caddy if wanted
    env_file: secrets.env
    volumes:
      - ./data:/data
      - ./config:/config
      - ./cache:/cache
      - ~/.config/rclone:/root/.config/rclone:ro
      - /:/backup-sources:ro     # read-only view of host volumes to back up
    environment:
      BACKREST_DATA: /data
      BACKREST_CONFIG: /config/config.json
      XDG_CACHE_HOME: /cache
```

- [ ] **Step 3: Encrypt the restic password**

```bash
cd thriller-bark/backrest
echo "RESTIC_PASSWORD=$(openssl rand -hex 32)" > secrets.env
sops -e -i secrets.env && grep -q 'ENC\[' secrets.env && echo "ENCRYPTED OK"
```

- [ ] **Step 4: Deploy + create repos + plans in Backrest UI [OPERATOR]**

- Repo A: `rclone:protondrive:the-sea` — backs up **all** selected paths (dawarich db/storage, komodo db, caddy data).
- Repo B: `rclone:mega:the-sea-critical` — backs up the **critical subset** only (Postgres dumps, `**/secrets.env` sources are already in git so skip; include finance/dawarich DB dumps).
- Schedule: daily; retention e.g. 7 daily / 4 weekly / 6 monthly.

- [ ] **Step 5: Run a backup + verify it lands**

```bash
rclone size protondrive:the-sea    # expect non-zero after first backup
rclone size mega:the-sea-critical  # expect non-zero
```

- [ ] **Step 6: Restore drill (the real test) [OPERATOR]**

```bash
# Restore dawarich's latest snapshot to a scratch dir and diff a known file.
docker exec backrest restic -r rclone:protondrive:the-sea restore latest \
  --target /tmp/restore-check --include /backup-sources/.../dawarich_storage
ls /tmp/restore-check/...   # expect the restored files present
```

Write the exact commands you ran into `docs/runbooks/restore-test.md`.

- [ ] **Step 7: Add stack to sync + commit**

```toml
[[stack]]
name = "backrest"
[stack.config]
server = "thriller-bark"
run_directory = "thriller-bark/backrest"
file_paths = ["compose.yaml"]
```

```bash
git add thriller-bark/backrest docs/runbooks/restore-test.md komodo/resource-sync.toml
git commit -m "feat: backrest backups to proton + mega with restore drill"
```

---

## Task 9: Observability — VictoriaMetrics + Loki + Grafana + Alloy

**Files:**
- Create: `thriller-bark/observability/compose.yaml`
- Create: `thriller-bark/observability/alloy-config.alloy`
- Create: `thriller-bark/observability/secrets.env` (SOPS-encrypted; Grafana admin password)
- Modify: `komodo/resource-sync.toml`, `thriller-bark/caddy/Caddyfile`

**Interfaces:**
- Consumes: all Docker nodes.
- Produces: Grafana at `https://grafana.<DOMAIN>` showing metrics + logs from Thriller Bark and Going Merry.

- [ ] **Step 1: Write `thriller-bark/observability/compose.yaml`**

```yaml
services:
  victoriametrics:
    image: victoriametrics/victoria-metrics:latest
    container_name: victoriametrics
    restart: unless-stopped
    command: ["-storageDataPath=/vmdata", "-retentionPeriod=6"]
    volumes: ["./vmdata:/vmdata"]
    ports: ["127.0.0.1:8428:8428"]
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    command: ["-config.file=/etc/loki/local-config.yaml"]
    volumes: ["./loki-data:/loki"]
    ports: ["127.0.0.1:3100:3100"]
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    env_file: secrets.env
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GF_ADMIN_PASSWORD}
      GF_SERVER_ROOT_URL: https://grafana.<DOMAIN>
    volumes: ["./grafana-data:/var/lib/grafana"]
    ports: ["127.0.0.1:3001:3000"]
  alloy:
    image: grafana/alloy:latest
    container_name: alloy
    restart: unless-stopped
    command: ["run", "/etc/alloy/config.alloy", "--server.http.listen-addr=0.0.0.0:12345"]
    volumes:
      - ./alloy-config.alloy:/etc/alloy/config.alloy:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /var/log:/var/log:ro
```

- [ ] **Step 2: Write `thriller-bark/observability/alloy-config.alloy`** (scrape docker + host, tail logs, ship to VM/Loki)

```alloy
prometheus.exporter.unix "host" { }
prometheus.scrape "node" {
  targets    = prometheus.exporter.unix.host.targets
  forward_to = [prometheus.remote_write.vm.receiver]
}
discovery.docker "containers" { host = "unix:///var/run/docker.sock" }
prometheus.scrape "docker" {
  targets    = discovery.docker.containers.targets
  forward_to = [prometheus.remote_write.vm.receiver]
}
prometheus.remote_write "vm" {
  endpoint { url = "http://victoriametrics:8428/api/v1/write" }
}
loki.source.docker "logs" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.containers.targets
  forward_to = [loki.write.default.receiver]
}
loki.write "default" {
  endpoint { url = "http://loki:3100/loki/api/v1/push" }
}
```

- [ ] **Step 3: Encrypt Grafana password**

```bash
cd thriller-bark/observability
echo "GF_ADMIN_PASSWORD=$(openssl rand -hex 20)" > secrets.env
sops -e -i secrets.env && grep -q 'ENC\[' secrets.env && echo "ENCRYPTED OK"
```

- [ ] **Step 4: Deploy + add Grafana route to Caddy**

Add to `Caddyfile`:
```caddyfile
	@grafana host grafana.<DOMAIN>
	handle @grafana { reverse_proxy thriller-bark:3001 }
```

- [ ] **Step 5: Install Alloy on Going Merry [OPERATOR]** — as a second Alloy container in a small compose on going-merry, `remote_write` pointing at `http://thriller-bark:8428` and `loki` at `http://thriller-bark:3100` over the tailnet.

- [ ] **Step 6: Add Grafana data sources [OPERATOR]** — VictoriaMetrics (Prometheus type, `http://victoriametrics:8428`) and Loki (`http://loki:3100`). Import dashboard IDs 1860 (node) and a docker dashboard.

- [ ] **Step 7: Verify**

```bash
curl -fsS "http://localhost:8428/api/v1/query?query=up" | grep -q '"result"' && echo "METRICS OK"
curl -fsS "http://localhost:3100/ready" | grep -qi ready && echo "LOKI OK"
curl -fsS -o /dev/null -w "%{http_code}\n" https://grafana.<DOMAIN>   # expect 200
```

Expected: metrics from both nodes visible in Grafana; logs queryable in the Loki explore view.

- [ ] **Step 8: Add stack to sync + commit**

```toml
[[stack]]
name = "observability"
[stack.config]
server = "thriller-bark"
run_directory = "thriller-bark/observability"
file_paths = ["compose.yaml"]
```

```bash
git add thriller-bark/observability thriller-bark/caddy/Caddyfile komodo/resource-sync.toml
git commit -m "feat: observability stack (vm+loki+grafana+alloy)"
```

---

## Task 10: Disaster-recovery runbook + foundation sign-off

**Files:**
- Create: `docs/runbooks/disaster-recovery.md`
- Create: `docs/architecture.md`

**Interfaces:**
- Consumes: everything above.
- Produces: written DR procedure + a condensed living architecture doc.

- [ ] **Step 1: Write `docs/runbooks/disaster-recovery.md`**

Document the rebuild-a-dead-node path: (1) provision host, (2) join tailnet (Task 2 script), (3) install Docker + periphery (Task 4), (4) place age key, (5) Komodo redeploys stacks from git, (6) restore data from Backrest (Task 8 restore drill). Include the exact commands.

- [ ] **Step 2: Write `docs/architecture.md`** — condensed from the spec, kept current as the living overview.

- [ ] **Step 3: Foundation acceptance check (spec §8)** — verify all six criteria pass:

```
1. tailscale status            → 4 nodes active
2. Komodo deploys from git     → dawarich stack green
3. https://dawarich.<DOMAIN>   → 200, valid wildcard cert, CF DNS-only
4. SOPS secret consumed        → dawarich running with decrypted POSTGRES_PASSWORD
5. Backrest → Proton + Mega    → both repos non-empty + restore drill passed
6. Grafana                     → metrics+logs from thriller-bark and going-merry
```

- [ ] **Step 4: Commit**

```bash
git add docs/runbooks/disaster-recovery.md docs/architecture.md
git commit -m "docs: disaster-recovery runbook + living architecture"
```

---

## Self-review notes

- **Spec coverage:** §4.1 mesh→T2, §4.2 Caddy→T6, §4.3 SOPS→T1, §4.4 Komodo→T3-5, §4.5 backups→T8, §4.6 observability→T9, §5 layout→T1, §8 acceptance→T10. Covered.
- **Out of scope (correctly deferred):** app migrations beyond the dawarich pilot (sub-projects 2-5), Sunny media wiring, Den Den Mushi HA backups.
- **Operator steps** are unavoidable — they need live credentials and console access. They're marked **[OPERATOR]** so an agent knows to hand off rather than fake them.
