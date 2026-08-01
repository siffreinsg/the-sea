# TODO

What's next. Ideas that aren't thought out yet are in [FUTURE.md](FUTURE.md); a task links
its plan in [plans/](plans/) once work starts.

## AI platform

### Sidekick stack

Tika, Postgres cutover, SearXNG, patchright, per-key budgets and the config review all
landed — [runbook](runbooks/wire-ai-into-an-app.md), [why no reranker](ADR/2026-07-28-no-reranking.md),
[why the Caddy relay](ADR/2026-07-29-caddy-relays-mesh-services-to-containers.md).

- [ ] Rework web search, SearXNG or otherwise. Scraping consumer engines from a datacenter
      IP CAPTCHAs, so it returns Wikipedia only. Both SearXNG alert rules paused until this
      lands.
- [ ] wikidata 403s on init and stays gone until restarted. Waiting on the upstream fix,
      then bump the image pin.

## Services

### Media

- [ ] Bazarr — [plan](plans/2026-07-25-bazarr.md)
- [ ] Wizarr — [plan](plans/2026-07-25-wizarr.md)

### Files and documents

- [ ] Syncthing, including the public 22000 port — [plan](plans/2026-07-26-syncthing.md)
- [ ] Paperless-ngx, blocked on Syncthing — [plan](plans/2026-07-26-paperless-ngx.md)
- [ ] Karakeep — [plan](plans/2026-07-26-karakeep.md)

### Tools

- [ ] Forgejo — [plan](plans/2026-07-26-forgejo.md)
- [ ] Wallos — [plan](plans/2026-07-26-wallos.md)
- [ ] Homepage — [plan](plans/2026-07-25-homepage.md)

## Security

### Edge

- [ ] Narrow the `your_spotify` `/api/*` bypass — [plan](plans/2026-07-26-your-spotify-api-bypass.md).
      Until it lands, `allowRegistrations: false` must stay off.

### Audit

- [ ] Scan the edge from off-network, and read the Oracle VCN security list — hairpin NAT
      can't prove which layer closes what
