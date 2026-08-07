# TODO

What's next. Ideas that aren't thought out yet are in [FUTURE.md](FUTURE.md); a task links
its plan in [plans/](plans/) once work starts.

## Misc

- [ ] Fix `/opt/the-sea`'s git-triggered pull on TB
- [ ] Collect traces from Komodo
- [ ] Remove noise from Grafana logs, metrics and traces
- [ ] Repair Grafana going-merry collection
- [ ] Blackbox LAN probes from Baratie's Alloy — not yet planned

## AI platform

### Sidekick stack

- [ ] Rework web search, SearXNG or otherwise.
- [ ] wikidata 403s on init. Waiting on the upstream fix, then bump the image pin.

## Services

### Media

- [ ] Bazarr — [plan](plans/2026-07-25-bazarr.md)
- [ ] Wizarr — [plan](plans/2026-07-25-wizarr.md)
- [ ] Fix cross-seed on qui
- [ ] Suggestarr — not yet planned
- [ ] Pulsarr — not yet planned
- [ ] Prunerr — not yet planned

### Finance

- [ ] Port Actual rules from the encrypted budget — [plan](plans/2026-08-06-actual-rules-port.md)
- [ ] Mine Actual rules from history — [plan](plans/2026-08-06-actual-rules-mining.md)
- [ ] LLM categorization of leftovers — [plan](plans/2026-08-06-actual-llm-categorization.md)

### Files and documents

- [ ] n8n automation to detect conflicting files on syncthing
- [ ] FileBrowser

### Tools

- [ ] Digarr (Spotify support) — not yet planned

## Security

### Audit

- [ ] Scan the edge from off-network, and read the Oracle VCN security list — hairpin NAT
      can't prove which layer closes what

### Networking

- [ ] Grafana IP tracking + anomaly alerts — not yet planned
