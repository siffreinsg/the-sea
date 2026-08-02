# Renovate opens PRs for new tags; Komodo polls digests under the pinned tag

**2026-08-02 · Accepted**

Two different staleness problems, two tools. Komodo's `poll_for_updates`
(all stacks, [resources.toml](../../komodo/resources.toml)) only sees a new
digest under the *same* pinned tag — a `4.38` rebuild, not a `4.39` release.
It can't tell you a new version exists. Renovate watches the registry for
new tags and opens a PR bumping the pin in `compose.yaml`, so a real version
change gets reviewed before it lands, same as any other diff.

`auto_update = true` (Authelia, n8n) still applies unreviewed digest
changes under the current tag — accepted for Authelia to close the CVE
window faster, at the cost of unreviewed breakage risk on the auth gateway.

Consequences:

- Two independent update paths per stack: Renovate PR for a tag bump,
  Komodo digest-poll for same-tag drift. Neither implies the other ran.
- `renovate.json` needs `dockerCompose.fileMatch` since files are named
  `compose.yaml`, not Renovate's default `docker-compose*.yaml`.
