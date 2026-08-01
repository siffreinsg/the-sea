# Bot hardening: fail2ban + caddy-ratelimit, not CrowdSec or orange-cloud

**2026-08-02 · Accepted**

TB's SSH (22) and Caddy edge (80/443), and GM's SSH (4747), take constant bot traffic with
no rate-limiting or banning in place. Considered three approaches.

**CrowdSec rejected.** Community threat-intel plus behavioral bans, but needs a bouncer
plugin (custom Caddy image beyond the plugin swap below), an agent container, and its own
database — a chain of moving parts disproportionate to a 2-node personal stack, and one
more thing that fails open (bouncer down ≠ traffic blocked) rather than closed.

**Flipping Cloudflare to orange-cloud rejected.** Reverses
[the grey-cloud ADR](2026-07-19-caddy-single-public-edge.md)'s deliberate DNS-only stance —
no proxying so Caddy sees real client IPs and owns TLS end-to-end. Free bot/WAF layer, but
changes a decision made for reasons unrelated to bots.

**Decision: fail2ban (SSH + a Caddy-log jail) and `caddy-ratelimit` (per-IP inline caps).**
fail2ban is one tool covering both surfaces — no new container, tails a log, bans via
iptables. `caddy-ratelimit` costs one `--with` line: `thriller-bark/caddy/Dockerfile`
already builds a custom image via `xcaddy` for the Cloudflare DNS plugin.

Consequences:

- fail2ban bans are coarse (whole IP, ban window) — a shared/CGNAT IP with one bad actor
  loses everyone behind it for the ban window. Accepted for a low-traffic personal stack.
- Two more configs to keep from drifting off the live hosts: `thriller-bark/fail2ban/`,
  `going-merry/fail2ban/`, `docs/runbooks/install-fail2ban.md`.
