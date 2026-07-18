#!/usr/bin/env bash
# bootstrap-wireguard.sh — configure a node on the-sea overlay (10.10.0.0/24).
#
# Hub (Thriller Bark):
#   sudo ./bootstrap-wireguard.sh hub 10.10.0.1 51820
# Spoke (dials the hub):
#   sudo ./bootstrap-wireguard.sh spoke 10.10.0.2 <HUB_PUBKEY> <HUB_PUBLIC_IP>:51820
#
# On nodes with no kernel WireGuard module (e.g. Going Merry/OpenVZ), install
# wireguard-go and export WG_USERSPACE=1 before bringing the tunnel up.
#
# Private keys are generated locally and never leave the host. Only the printed
# public key is shared (safe to commit to the repo peer table).
set -euo pipefail

ROLE="${1:?role: hub|spoke}"
ADDR="${2:?overlay ip, e.g. 10.10.0.1}"
WGDIR=/etc/wireguard
umask 077
mkdir -p "$WGDIR"

if [ ! -f "$WGDIR/privatekey" ]; then
  wg genkey | tee "$WGDIR/privatekey" | wg pubkey > "$WGDIR/publickey"
fi
PRIV=$(cat "$WGDIR/privatekey")

case "$ROLE" in
  hub)
    PORT="${3:-51820}"
    cat > "$WGDIR/wg0.conf" <<EOF
[Interface]
Address = ${ADDR}/24
ListenPort = ${PORT}
PrivateKey = ${PRIV}
# Add one [Peer] per spoke with:
#   wg set wg0 peer <SPOKE_PUBKEY> allowed-ips <SPOKE_OVERLAY_IP>/32
#   wg-quick save wg0
EOF
    ;;
  spoke)
    HUB_PUB="${3:?hub public key}"
    HUB_ENDPOINT="${4:?hub endpoint host:port}"
    cat > "$WGDIR/wg0.conf" <<EOF
[Interface]
Address = ${ADDR}/24
PrivateKey = ${PRIV}

[Peer]
PublicKey = ${HUB_PUB}
Endpoint = ${HUB_ENDPOINT}
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
EOF
    ;;
  *) echo "role must be hub|spoke" >&2; exit 1 ;;
esac

echo "==> wg0.conf written for ${ADDR}"
echo "==> Public key (share this):"
cat "$WGDIR/publickey"
echo
if [ "${WG_USERSPACE:-0}" = "1" ]; then
  echo "Bring up (userspace): WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go wg-quick up wg0"
else
  echo "Bring up (kernel):    wg-quick up wg0   (enable on boot: systemctl enable wg-quick@wg0)"
fi
