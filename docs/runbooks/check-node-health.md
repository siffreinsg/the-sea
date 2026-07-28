# Check node health

Run on the node itself. The machines and their limits: [nodes](../domains/nodes.md).

```bash
uname -r; ls /var/run/reboot-required 2>/dev/null && cat /var/run/reboot-required.pkgs
sudo apt update && sudo apt upgrade -y
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
sudo ss -tulpn | grep -v 127.0.0.1                   # nothing unexpected on a public bind
```

The last one is the bind rule's check: on GM everything should show `100.64.0.1`, on TB
only 80/443/22 should be reachable from outside
([the rule](../ADR/2026-07-19-services-bind-private-addresses.md)).
