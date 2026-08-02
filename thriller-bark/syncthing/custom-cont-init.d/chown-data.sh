#!/usr/bin/with-contenv bash
# LSIO only auto-chowns /config; /data is a separate volume Docker creates as root:root.
chown "${PUID}:${PGID}" /data
