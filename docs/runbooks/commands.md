# Common commands

Quick reference for the commands you run often. Paths assume the repo at
`/opt/the-sea` on a node, `~/projects/the-sea` locally.

## Secrets (SOPS + age)

```bash
# Encrypt a plaintext secrets.env in place (local, before commit)
sops -e -i <ship>/<app>/secrets.env

# Edit an already-encrypted file (opens decrypted in $EDITOR, re-encrypts on save)
sops <ship>/<app>/secrets.env

# Decrypt to .env on a node at deploy time (key is root-owned)
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sops -d secrets.env > .env

# Verify a round-trip / that a key is present
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sops -d <ship>/<app>/secrets.env

# Check the age key on a node matches the .sops.yaml recipient
age-keygen -y /etc/sops/age.key
```

## Caddy (Thriller Bark)

```bash
# Apply a Caddyfile change pulled from git. Use force-recreate, NOT `caddy reload`:
# git pull swaps the file's inode, so the single-file bind-mount serves stale
# content and reload re-reads the same stale inode. Recreate re-resolves the mount.
cd /opt/the-sea/thriller-bark/caddy && docker compose up -d --force-recreate

# Only safe when the Caddyfile was edited in place (not via git pull):
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# See what config the running container actually has (0 hits = stale mount)
docker exec caddy caddy adapt --config /etc/caddy/Caddyfile 2>/dev/null | grep -c <name>

# Logs (ACME/DNS-01 errors show here)
docker logs caddy
```

## Deploy a stack on a node

```bash
cd /opt/the-sea && git pull
cd <ship>/<app>
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sops -d secrets.env > .env
docker compose up -d          # add --build if it has a Dockerfile
docker logs <container>
```

## Headscale (Thriller Bark)

```bash
curl -s http://127.0.0.1:8080/health          # health, bypassing Caddy
docker exec headscale headscale users list
docker exec headscale headscale preauthkeys create --user <id> --reusable --expiration 24h
docker exec headscale headscale nodes list     # joined nodes
```

## Mesh (Tailscale client, any node)

```bash
tailscale status
tailscale ping <hostname>
```
