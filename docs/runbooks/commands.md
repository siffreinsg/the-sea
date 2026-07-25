# Commands

Copy-paste reference. `<ship>` = `thriller-bark` | `going-merry`. Repo is `/opt/the-sea`
on a node. Anything needing explanation lives in [`docs/domains/`](../domains/), not here.

## Secrets

```bash
sops -e -i <ship>/<app>/secrets.env                  # encrypt in place (local, pre-commit)
sops <ship>/<app>/secrets.env                        # edit decrypted in $EDITOR
sops set <ship>/<app>/secrets.env '["KEY"]' '"<value>"'   # set one scalar, no round trip

# on a node — always with the umask, the decrypt inherits root's 022 otherwise
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sh -c 'umask 077; sops -d secrets.env > .env'
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sops -d <ship>/<app>/secrets.env   # verify round-trip
age-keygen -y /etc/sops/age.key                      # key matches .sops.yaml recipient?

# hashes needing the app's own CLI — omit --password, it prompts
docker exec -it authelia authelia crypto hash generate pbkdf2 --variant sha512
docker exec -it authelia authelia crypto hash generate argon2 --variant argon2id

# audit file modes — expect no output
sudo find /etc/komodo /var/backups/the-sea -type f \
  \( -name '.env' -o -name 'rclone.conf' -o -name '*.gz' \) -perm -o=r
```

## Deploy

```bash
# normal path: Komodo Sync -> Deploy. Manual fallback:
cd /opt/the-sea && git pull
cd <ship>/<app>
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sh -c 'umask 077; sops -d secrets.env > .env'
sudo docker compose up -d --force-recreate          # --build if it has a Dockerfile
docker logs <container> --tail 50
```

The control plane (`komodo` stack) updates differently — [deploy](../domains/deploy.md).

## Caddy

```bash
docker exec caddy caddy validate --config /etc/caddy/Caddyfile    # BEFORE a rebuild lands
cd /opt/the-sea/thriller-bark/caddy && sudo docker compose up -d --force-recreate --build
docker logs caddy                                    # ACME / DNS-01 errors
docker exec caddy caddy adapt --config /etc/caddy/Caddyfile | grep -c <name>   # 0 = stale mount
```

Never `caddy reload` after a `git pull` — the file is inode-pinned.

## Backups & dumps

```bash
sudo systemctl start the-sea-dumps.service           # run now
systemctl status the-sea-dumps.service --no-pager    # want inactive (dead), status=0
systemctl list-timers the-sea-dumps.timer            # next 03:00 UTC
ls -l /var/backups/the-sea/dumps/                    # all present, non-trivial, 0600
sudo journalctl -u the-sea-dumps.service -n 30
```

Backrest UIs: `https://backrest-{tb,gm}.siffreinsigy.me`.

## Mesh & firewall

```bash
tailscale status
tailscale ping <hostname>
curl -s http://127.0.0.1:8080/health                 # headscale, bypassing Caddy
docker exec headscale headscale nodes list
docker exec headscale headscale users list
docker exec headscale headscale preauthkeys create --user <id> --reusable --expiration 24h

# containers must NOT reach the mesh — this should hang, then time out
docker exec n8n node -e 'require("net").connect(3100,"100.64.0.1")\
  .on("error",e=>console.log("blocked:",e.code)).on("connect",()=>console.log("REACHABLE"))'
sudo iptables -t raw -S PREROUTING | head -3
sudo systemctl restart the-sea-mesh-guard
```

## Observability

```bash
curl -s 'http://100.64.0.1:8428/api/v1/query?query=up' | jq '.data.result[].metric'
curl -s -G 'http://100.64.0.1:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={node="going-merry"}' --data-urlencode 'limit=3'
curl -s http://127.0.0.1:12345/-/ready && docker logs alloy --since 10m   # on the node itself

# pull live Grafana state back into the repo (service-account token, Admin role)
TOK="<token>"; BASE="https://grafana.siffreinsigy.me"
curl -s -H "Authorization: Bearer $TOK" \
  "$BASE/api/v1/provisioning/alert-rules/export?format=yaml" > provisioning/alerting/rules.yaml
curl -s -H "Authorization: Bearer $TOK" "$BASE/api/dashboards/uid/<uid>" \
  | jq .dashboard > dashboards/<name>.json
```

## Node health

```bash
uname -r; ls /var/run/reboot-required 2>/dev/null && cat /var/run/reboot-required.pkgs
sudo apt update && sudo apt upgrade -y
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
sudo ss -tulpn | grep -v 127.0.0.1                   # nothing unexpected on a public bind
```
