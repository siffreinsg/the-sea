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

## One-time cutover: the network redesign ([why](../ADR/2026-08-01-per-stack-networks-and-headscale-acl.md))

Order matters — later steps depend on earlier ones being live. Both nodes.

1. `docker network create edge && docker network create ai-backends` on TB (Komodo won't
   create these — they're hand-created, same as the old `the-sea-internal`).
2. Deploy `gm-relay` before main Caddy — Caddy's Caddyfile already points at its loopback
   ports, so Caddy fails every GM-bound hostname until gm-relay is actually up.
3. Redeploy every stack that joined `edge`/`ai-backends`, then Caddy last.
4. `headscale nodes tag -i <id> -t tag:tb` / `tag:gm` on both nodes' Headscale
   registration, then `docker exec headscale headscale nodes list` and confirm both show
   their tag. Skipping this leaves the ACL default-deny — every GM-backed hostname and
   the metrics pipeline go dark at once, with nothing pointing at why.
5. `sudo systemctl enable --now the-sea-mesh-guard` on **both** nodes — TB already had
   this unit; GM is new
   (`sudo ln -sf /opt/the-sea/going-merry/firewall/the-sea-mesh-guard.service
   /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now
   the-sea-mesh-guard`). Verify with `docs/runbooks/check-the-mesh.md`.
6. Smoke-test all 15 hostnames in `docs/REFERENCE.md` § Web UIs.
