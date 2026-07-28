# Plan — close Caddy's admin API (TB)

Closes the `admin off` item in [future](../FUTURE.md) and the caveat in
[ingress](../domains/ingress.md). Delete this doc when it lands.

**The problem.** `127.0.0.1:2019` is an unauthenticated **read/write config** endpoint
for any local user on TB. `admin off` was blocked because Alloy scrapes `/metrics` off
that same endpoint (`thriller-bark/alloy/config.alloy`, `prometheus.scrape "caddy"`).

**The fix.** Serve metrics from a normal Caddy site on its own loopback port, repoint
Alloy at it, then turn the admin API off. Two files, one commit.

Verified 2026-07-25: Caddy is pinned `2.11.4` (`thriller-bark/caddy/Dockerfile`), and
`metrics` exists there both as a global option (already set) and as a **handler
directive** — `modules/metrics/metrics.go` registers `http.handlers.metrics`, and
`caddyconfig/httpcaddyfile/directives.go` lists `metrics` in the standard order.

## Why this is safe here

- **Nothing uses the admin API for reloads.** The rule is already
  `up -d --force-recreate`, never `caddy reload` — the Caddyfile is bind-mounted and
  inode-pinned ([deploy](../domains/deploy.md), [ingress](../domains/ingress.md)).
  `admin off` therefore costs nothing operationally.
- **Both containers are `network_mode: host`**, so a loopback port works for Alloy
  exactly the way `:2019` does today. No new exposure: 2020 is loopback-only and the
  mesh-guard/firewall story is unchanged.

## The diff

`thriller-bark/caddy/Caddyfile`, global block:

```caddyfile
{
	email hello@siffreinsigy.me
	acme_dns cloudflare {env.CF_API_TOKEN}
	metrics
	admin off
}
```

…and a new site block, above `*.siffreinsigy.me`:

```caddyfile
# Metrics only. Loopback, plaintext, no ACME. Exists so `admin off` above can be set
# without blinding Alloy — the admin endpoint on :2019 was unauthenticated read/write
# config for any local user.
http://127.0.0.1:2020 {
	metrics /metrics
}
```

`thriller-bark/alloy/config.alloy`:

```river
prometheus.scrape "caddy" {
  targets    = [{ __address__ = "127.0.0.1:2020", job = "caddy" }]
  forward_to = [prometheus.relabel.add_node.receiver]
}
```

## Deploy

**Neither block was run through `caddy validate`** — no docker on the machine this was
written from. The `\` line-continuation used in the Wizarr plan's matcher *is* valid
(v2.11.4 `caddyconfig/caddyfile/lexer.go`: "newlines can be escaped to chain arguments
onto multiple lines"), but before deploying either change, run:

```bash
docker run --rm -v "$PWD/thriller-bark/caddy/Caddyfile:/Caddyfile:ro" \
  caddy:2.11.4-alpine caddy validate --adapter caddyfile --config /Caddyfile
```


Caddy first, then Alloy — a scrape gap is harmless, a metrics-less Caddy is not the
thing to leave running while you go find the other file. Both are
`up -d --force-recreate` (Caddy also `--build`).

## Docs to correct when it lands

Not optional — [ingress](../domains/ingress.md) currently states the **opposite** rule:

- `docs/domains/ingress.md`, the `127.0.0.1:2019` bullet: it says "`admin off` is not
  available because Alloy scrapes it". Replace with the new rule — admin API off,
  metrics served from `127.0.0.1:2020`, Alloy scrapes that.
- `docs/FUTURE.md`: drop the Caddy-admin line from the open-security list entirely.
- Delete this plan.

## Done when

`curl -s 127.0.0.1:2020/metrics | head` returns Prometheus text on TB,
`curl -s 127.0.0.1:2019/config/` connection-refuses, the `caddy` job is `up` in
Grafana, and a public site still serves.

**The Caddy alert rule now uses `noDataState: Alerting`** (`fft01129bdvk0e`) — if
`caddy_config_last_reload_successful` stops arriving because the scrape moved to 2020 and
Alloy wasn't updated, it will fire, loudly and correctly. Don't silence it; fix the scrape.

**Check the `job="caddy"` series didn't change identity** — same job label, same
target semantics, so existing panels and any alert rules should carry over
untouched. If a panel goes blank, that's the thing that broke.
