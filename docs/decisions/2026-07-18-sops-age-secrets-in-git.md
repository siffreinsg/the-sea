# Secrets live in git, encrypted with SOPS + age

**2026-07-18 · Accepted · `2783d55`**

The disaster-recovery model is the whole point: clone the repo, drop in one key,
redeploy. That only works if secrets travel with the code.

`secrets.*` files are committed encrypted to a single age recipient. Each stack's
Komodo `pre_deploy` hook decrypts them into place at deploy time. The one out-of-band
artifact in the entire infra is that age private key, kept in a password manager and at
`/etc/sops/age.key` (root, 0600) on each node.

**Consequence:** losing the age key loses everything, and it is the single highest-value
secret in the estate. The decrypted outputs on-node need their own protection — see
[secrets](../domains/secrets.md), which is where this design was undone once already by
a default umask.
