# Check the mesh and the firewall

How it is wired: [networking](../domains/networking.md).

## Mesh

```bash
tailscale status
tailscale ping <hostname>
docker exec caddy curl -s http://headscale:8080/health   # headscale, bypassing Caddy's public edge
docker exec headscale headscale nodes list                # confirm both TB and GM show tag:tb / tag:gm — untagged is ACL default-deny
docker exec headscale headscale users list
docker exec headscale headscale preauthkeys create --user <id> --reusable --expiration 24h
```

## The container/tailnet guard and ACL

Containers must **not** reach the mesh
([why](../ADR/2026-07-25-mesh-guard-in-raw-prerouting.md)). The probe should hang, then
time out — on **both** nodes, the guard runs on each. A GM container probing TB hits both
the guard (always blocks) and the ACL's GM→TB default-deny (no rule exists), so a blocked
result alone doesn't tell you which mechanism fired; check `iptables -S` on the node under
test if you need to know.

```bash
docker exec n8n node -e 'require("net").connect(3100,"100.64.0.1")\
  .on("error",e=>console.log("blocked:",e.code)).on("connect",()=>console.log("REACHABLE"))'
sudo iptables -t raw -S PREROUTING | head -3
sudo systemctl restart the-sea-mesh-guard     # run on TB and GM — the unit is installed on both
```
