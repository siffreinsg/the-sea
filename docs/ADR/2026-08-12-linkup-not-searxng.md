# Web search is Linkup, not self-hosted SearXNG

**2026-08-12 · Accepted**

what: Open-WebUI's web search calls the Linkup API. The SearXNG stack is deleted.

why: metasearch scrapes Google and Bing frontends, and both nodes sit on datacenter IPs
those frontends block by range. brave, duckduckgo, qwant and startpage all CAPTCHA'd on
first real use (2026-07-31) and stayed banned; both SearXNG alert rules had been paused
since, because a permanently degraded engine set is a steady state, not an incident.
Self-hosting did not fail on cost or effort, it failed on the IP.

consequence: a paid per-query API, and a third party sees the queries. No degraded mode
left — a banned engine used to leave the others, an expired key takes web search out
entirely, and nothing alerts on it. Accepted, not overlooked. The `hostnames` regex filter
has no equivalent. GM drops a stack, a relay hop, an ACL port and a scrape job.

alternative: a residential-IP egress proxy for SearXNG — a second moving part, a second
subscription, still scraping engines that fight scrapers. `WEB_SEARCH_ENGINE=external` was
rejected too: another service to host when a native `linkup` engine already ships.
