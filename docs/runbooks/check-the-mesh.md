# Check the mesh and the firewall

How it is wired: [networking](../domains/networking.md).

## Mesh

```bash
tailscale status
tailscale ping <hostname>
curl -s http://127.0.0.1:8080/health                 # headscale, bypassing Caddy
docker exec headscale headscale nodes list
docker exec headscale headscale users list
docker exec headscale headscale preauthkeys create --user <id> --reusable --expiration 24h
```

## The container/tailnet guard

Containers must **not** reach the mesh
([why](../ADR/2026-07-25-mesh-guard-in-raw-prerouting.md)). The probe should hang, then
time out.

```bash
docker exec n8n node -e 'require("net").connect(3100,"100.64.0.1")\
  .on("error",e=>console.log("blocked:",e.code)).on("connect",()=>console.log("REACHABLE"))'
sudo iptables -t raw -S PREROUTING | head -3
sudo systemctl restart the-sea-mesh-guard
```
