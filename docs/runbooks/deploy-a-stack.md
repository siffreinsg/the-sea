# Deploy a stack

Normal path is Komodo: **Sync → Deploy**. This is the manual fallback and the Caddy
special case. How the sync works: [deploy](../domains/deploy.md).

## Manual deploy on a node

```bash
cd /opt/the-sea      # a Komodo repo resource pulls this on push; `git pull` only if impatient
cd <ship>/<app>
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sh -c 'umask 077; sops -d secrets.env > .env'
sudo docker compose up -d --force-recreate          # --build if it has a Dockerfile
docker logs <container> --tail 50
```

The control plane (`komodo` stack) updates differently — [deploy](../domains/deploy.md).

## Caddy

Validate **before** a rebuild lands, and never `caddy reload` after a `git pull`: the file
is inode-pinned.

```bash
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
cd /opt/the-sea/thriller-bark/caddy && sudo docker compose up -d --force-recreate --build
docker logs caddy                                    # ACME / DNS-01 errors
docker exec caddy caddy adapt --config /etc/caddy/Caddyfile | grep -c <name>   # 0 = stale mount
```
