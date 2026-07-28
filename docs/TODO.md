# TODO

What's next. Ideas that aren't thought out yet are in [FUTURE.md](FUTURE.md); a task links
its plan in [plans/](plans/) once work starts.

## AI platform

### Sidekick stack

Build order and verification commands: [plan](plans/2026-07-26-sidekick-stack.md)

- [x] Tika (TB). Reranking dropped after measurement — [why](ADR/2026-07-28-no-reranking.md)
- [ ] SearXNG on GM — `json` must be in `settings.yml` `search.formats`
- [ ] Firecrawl (API + Redis + Playwright) on GM — must answer `/v2/scrape`
- [ ] Postgres cutover — destructive, do last
- [ ] Per-key budgets on the LiteLLM keys
- [ ] Config review, read when a value looks wrong — [plan](plans/2026-07-26-ai-platform-config-review.md)

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
- [ ] Close the Caddy admin API — [plan](plans/2026-07-25-caddy-admin-off.md)

### Audit

- [ ] Scan the edge from off-network, and read the Oracle VCN security list — hairpin NAT
      can't prove which layer closes what
