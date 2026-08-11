# 🌊 The Sea

Infrastructure-as-code for a self-hosted homelab across four nodes: **Thriller Bark**
(Oracle ARM), **Going Merry** (Omgserv VPS), **The Thousand Sunny** (Ultra.cc) and
**Baratie** (Raspberry Pi).

Komodo pulls this repo onto each node and runs the compose stacks. Caddy on Thriller Bark
is the only public door, secrets are SOPS-encrypted in-repo, and backups go to Proton Drive
and Mega through restic.

## Layout

Top-level dirs are per-ship and map onto Komodo server targets. Cross-cutting concerns live
at root: `komodo/`, `docs/`, `.sops.yaml`.

## Docs

| | |
|---|---|
| [`docs/PROJECT.md`](docs/PROJECT.md) | What this is, its constraints and non-goals |
| [`docs/TODO.md`](docs/TODO.md) | What's next |
| [`docs/ARCHI.md`](docs/ARCHI.md) | How it fits together, entry point to the domains |
| [`docs/REFERENCE.md`](docs/REFERENCE.md) | Addresses, ports, schedules |
