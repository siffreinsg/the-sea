# TODO

What's next. Ideas that aren't thought out yet are in [FUTURE.md](FUTURE.md); a task links
its plan in [plans/](plans/) once work starts.

## AI platform

### Sidekick stack

Build order and verification commands: [plan](plans/2026-07-26-sidekick-stack.md)

- [x] Tika (TB). Reranking dropped after measurement — [why](ADR/2026-07-28-no-reranking.md)
- [x] Postgres cutover, one database per app, Open-WebUI on v0.11.0
- [x] SearXNG on GM, through Caddy's `:8090` relay rather than the mesh
      ([why](ADR/2026-07-29-caddy-relays-mesh-services-to-containers.md))
- [ ] **wikidata 403s on init**, so SearXNG runs 6 engines and the drift alert is paused.
      `query.wikidata.org` rejects the SPARQL call the engine makes at worker boot, and a
      failed init is never retried — the engine is gone until a restart. **Waiting on an
      upstream fix**, so the action here is an image bump, not a config change. When it
      lands: bump the pin, restart, confirm 7 engines report, unpause `cft0290searxng2`.
      If upstream drops the engine instead, remove it from `keep_only` and retune to 6.
- [ ] Firecrawl (API + Redis + Playwright) on GM — must answer `/v2/scrape`, relay on `:8091`
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
