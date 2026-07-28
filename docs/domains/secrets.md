# Secrets

Encrypted `secrets.*` files are committed; each stack's Komodo `pre_deploy` hook decrypts
them into place on-node, where the output is gitignored
([the model](../ADR/2026-07-18-sops-age-secrets-in-git.md)). Decryption needs sudo —
the age key is root-owned, 0600.

## The rule that keeps the model honest

**Everything sops writes on-node must be 0600.** `sops -d … > file` runs under root's
default `022` umask, so the decrypted output lands world-readable while the age key itself
is correctly 0600 — the decrypt step throws away exactly the protection the design exists
to provide — Authelia's OIDC token-signing private key, the Cloudflare API token and the
restic/rclone credentials, readable by any local account on both nodes.

- Every `pre_deploy.command` in `komodo/resources.toml` is prefixed `umask 077 &&`. Keep
  it there, including on any new stack.
- Same in every `backup.sh` and in each node's `backups/run.sh` — DB dumps are app data in
  the clear (Dawarich's is a full GPS history).
- **`docker cp` ignores the umask**, carrying the container-side mode across instead. Any
  dump that leaves its container that way needs an explicit `chmod 600`.
- `umask` only affects **new** files, so fixing existing ones is a one-time `chmod`, not a
  redeploy.

Audit, expecting no output:

```bash
find /etc/komodo /var/backups/the-sea -type f \
  \( -name '.env' -o -name 'rclone.conf' -o -name '*.gz' \) -perm -o=r
```

## Handling rules

- **A new decrypt target must be added to `.gitignore`.** One `git add -A` in a clone
  where the Authelia decrypt has run would commit the OIDC signing key to history —
  permanently, and distributed to every clone.
- **Never pass a secret as a CLI argument.** It lands in `~/.bash_history` and is visible
  in `ps` to every local user while the command runs. Authelia's `crypto hash generate`
  prompts when `--password` is omitted. If a tool leaves no choice, a leading space plus
  `HISTCONTROL=ignoreboth` is a backstop, not a plan.
- **Secrets needing the app's own CLI** (argon2 passwords, pbkdf2 OIDC client secrets):
  there is no Docker on the dev machine, so `docker exec` on-node, then set the value
  locally with `sops set '<path>' '"<value>"'` — a single scalar at an indexed path, which
  avoids a full decrypt/re-encrypt round trip. Plain secrets (session keys, DB passwords)
  are generated locally with `openssl rand`.
- **Never `sops set` the `clients` path** in Authelia's `secrets.oidc.yml` — it holds every
  existing client and setting it replaces the array wholesale. Add a client by editing the
  file.
- **Don't put YAML comments inside a list item in a sops file.** Adding an OIDC client with
  `#` comments among its keys re-encrypted cleanly and then failed every decrypt with
  `MAC mismatch` — sops encrypts comments as their own entries and mis-accounts for them
  nested in a sequence. The same edit without comments round-trips fine. Symptom is
  alarming and looks like key corruption; it isn't. Recovery is `git checkout` the file,
  since the encrypted copy is committed. Explanatory comments belong in the plan or domain
  doc, not inside the encrypted blob.

## Known cleartext, deliberately

- **Komodo's git PAT lives unencrypted in Mongo**, so the nightly `komodo-mongo.archive.gz`
  *is* a credential for the repo. The token is **read-only on `siffreinsg/the-sea` and must
  stay that way** — the repo is what the root-executed nightly scripts run from, so a
  write-capable token turns any local read into root on both nodes.
- **`/etc/komodo/periphery.config.toml`** holds the onboarding key in cleartext and is
  outside the sops pattern. Keep it 0600. It also has terminals enabled, which is how
  Komodo works — meaning **Komodo Core's own authentication is load-bearing for root on
  both nodes**.
- **Backrest's `config.json` and Komodo's alerters** are deliberately not in git at all —
  [why, and what that costs at DR time](../ADR/2026-07-25-backrest-and-alerters-stay-ui-managed.md).

## Blast radius worth knowing

**Alloy is the widest-privilege container in the fleet**: host netns, `/` mounted,
docker.sock. `:ro` on a socket only protects the file — the Docker API is fully usable
through it. It is necessary (cadvisor has no path-override args and needs `/rootfs`,
`/sys`, `/var/lib/docker` and `/run/containerd/containerd.sock` — omit that last one and
container-stats scraping breaks silently).

The part that matters: `/:/rootfs:ro` lets Alloy read **`/etc/sops/age.key`**, so an Alloy
compromise yields every secret on the node regardless of file modes. The file hygiene above
is defence-in-depth, not the mitigation — the mitigation would be fronting docker.sock with
a proxy.
