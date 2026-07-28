# Handle secrets

How the scheme works: [secrets](../domains/secrets.md). `<ship>` = `thriller-bark` |
`going-merry`; the repo is `/opt/the-sea` on a node.

## Edit and encrypt, locally

```bash
sops -e -i <ship>/<app>/secrets.env                  # encrypt in place (pre-commit)
sops <ship>/<app>/secrets.env                        # edit decrypted in $EDITOR
sops set <ship>/<app>/secrets.env '["KEY"]' '"<value>"'   # set one scalar, no round trip
```

## Decrypt on a node

```bash
# always with the umask — the decrypt inherits root's 022 otherwise
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sh -c 'umask 077; sops -d secrets.env > .env'
sudo SOPS_AGE_KEY_FILE=/etc/sops/age.key sops -d <ship>/<app>/secrets.env   # verify round-trip
age-keygen -y /etc/sops/age.key                      # key matches .sops.yaml recipient?
```

## Hashes that need the app's own CLI

Omit `--password`, it prompts. Never pass a secret as an argument.

```bash
docker exec -it authelia authelia crypto hash generate pbkdf2 --variant sha512
docker exec -it authelia authelia crypto hash generate argon2 --variant argon2id
```

## Audit file modes

Expect no output.

```bash
sudo find /etc/komodo /var/backups/the-sea -type f \
  \( -name '.env' -o -name 'rclone.conf' -o -name '*.gz' \) -perm -o=r
```
