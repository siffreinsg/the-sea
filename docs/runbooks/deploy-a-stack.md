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

Order matters — later steps depend on earlier ones being live.

0. **Pre-flight, before touching anything:** `sudo ss -lntp | grep 9120` on TB — confirms
   whether Komodo Core (host-mode, no `ports:` in its compose) actually listens on
   `0.0.0.0` today. If it answers loopback only, `komodo.siffreinsigy.me` will 502 after
   step 5 below and needs a bind override first, not a surprise mid-cutover. Also
   `sudo ss -tnp | grep 100.64.0.1` on TB — anything established outside the 11 ACL ports
   (`docs/REFERENCE.md`) dies silently the moment the ACL goes live in step 3.
1. On TB: `docker network create edge && docker network create ai-backends && docker
   network create n8n-edge` (Komodo won't create these — they're hand-created, same as
   the old `the-sea-internal`).
2. **Komodo resource Sync** picks up the new `gm-relay` stack entry in
   `komodo/resources.toml` — without this, step 4 has nothing to deploy.
3. Redeploy `headscale` (it joined `edge`), then immediately `headscale nodes tag -i <id>
   -t tag:tb` / `tag:gm` for **both** nodes, then `docker exec headscale headscale nodes
   list` and confirm both show their tag. Do this before any other `edge` stack redeploys
   — the ACL activates the moment Headscale restarts with the policy file mounted, and an
   untagged node is default-deny: every GM-bound flow (Alloy's 8428/3100/4317, gm-relay's
   hops) dies until tagging completes. Expect `headscale.siffreinsigy.me` itself to 502
   for this window — old Caddy still dials its now-removed `127.0.0.1:8080` publish, new
   Caddy isn't deployed yet. Harmless: no client needs the control plane mid-cutover.
4. Deploy `gm-relay` before main Caddy — Caddy's Caddyfile already points at its loopback
   ports, so Caddy fails every GM-bound hostname until gm-relay is actually up.
5. Redeploy every remaining stack that joined `edge`/`ai-backends`/`n8n-edge`, then Caddy
   last.
6. `sudo systemctl enable --now the-sea-mesh-guard` on **both** nodes — TB already had
   this unit; GM is new
   (`sudo ln -sf /opt/the-sea/going-merry/firewall/the-sea-mesh-guard.service
   /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now
   the-sea-mesh-guard`). Verify with `docs/runbooks/check-the-mesh.md`.
7. Smoke-test all 15 hostnames in `docs/REFERENCE.md` § Web UIs.
