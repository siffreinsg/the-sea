# Install fail2ban and the sshd hardening drop-in

Host-level, not a container — [why](../domains/networking.md). Run on both nodes.
`<node>` is `thriller-bark` or `going-merry`.

## Install (once per node)

```bash
sudo apt-get install -y fail2ban
sudo ln -sf /opt/the-sea/<node>/fail2ban/jail.local /etc/fail2ban/jail.local
sudo ln -sf /opt/the-sea/thriller-bark/fail2ban/filter.d/caddy-abuse.conf /etc/fail2ban/filter.d/caddy-abuse.conf   # TB only

# sshd drop-ins — shared hardening + this node's port/bind/user. Confirm the login
# user and public IP first: AllowUsers and ListenAddress both lock out anyone/anything
# that doesn't match.
sudo ln -sf /opt/the-sea/ssh/hardening.conf   /etc/ssh/sshd_config.d/50-hardening.conf
sudo ln -sf /opt/the-sea/<node>/ssh/local.conf /etc/ssh/sshd_config.d/60-local.conf
sudo sshd -t                              # validate before restarting
sudo systemctl restart ssh fail2ban
```

On TB, redeploy the `caddy` stack first (Dockerfile + Caddyfile changes need
`up -d --build --force-recreate`, per `docs/domains/deploy.md`) so
`/var/log/caddy/access.log` exists before the `caddy-abuse` jail starts.

## Verify

```bash
fail2ban-client status sshd
fail2ban-client status caddy-abuse        # TB only
ssh -o PubkeyAuthentication=no <user>@<host>   # must fail without a password prompt
```

From a **fresh terminal**, confirm a normal key-only login still works before closing the
session you're working in.

To lift a ban: `sudo fail2ban-client set <jail> unbanip <ip>`.
