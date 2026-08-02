# TODO

What's next. Ideas that aren't thought out yet are in [FUTURE.md](FUTURE.md); a task links
its plan in [plans/](plans/) once work starts.

## Misc

- [ ] Fix `/opt/the-sea`'s git-triggered pull on TB — `main` was stuck at `ffdff9e`
      (pre-redesign) despite the two `[[repo]]` webhook resources in
      `komodo/resources.toml`; found while restoring litellm-db, worked around with a
      manual `git pull`
- [ ] Configure Uptime Kuma to monitor The Sea
- [ ] Collect traces from Komodo
- [ ] Remove noise from Grafana logs, metrics and traces

## AI platform

### Sidekick stack

- [ ] Rework web search, SearXNG or otherwise. Scraping consumer engines from a datacenter
      IP CAPTCHAs, so it returns Wikipedia only. Both SearXNG alert rules paused until this
      lands.
- [ ] wikidata 403s on init and stays gone until restarted. Waiting on the upstream fix,
      then bump the image pin.

## Services

### Media

- [ ] Bazarr — [plan](plans/2026-07-25-bazarr.md)
- [ ] Wizarr — [plan](plans/2026-07-25-wizarr.md)
- [ ] Fix cross-seed on qui
- [ ] Doplarr — not yet planned
- [ ] Suggestarr — not yet planned
- [ ] Pulsarr — not yet planned
- [ ] Prunerr — not yet planned

### Files and documents

- [ ] n8n automation to detect conflicting files on syncthing
- [ ] Paperless-ngx — [plan](plans/2026-07-26-paperless-ngx.md)
- [ ] FileBrowser

### Tools

- [ ] Forgejo — [plan](plans/2026-07-26-forgejo.md)
- [ ] Wallos — [plan](plans/2026-07-26-wallos.md)
- [ ] Homepage — [plan](plans/2026-07-25-homepage.md)
- [ ] Digarr (Spotify support) — not yet planned

## Security

### Audit

- [ ] Scan the edge from off-network, and read the Oracle VCN security list — hairpin NAT
      can't prove which layer closes what

### Networking

- [ ] Grafana IP tracking + anomaly alerts — not yet planned
