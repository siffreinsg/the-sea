# Alerts go to Telegram, through Den Den Mushi

**2026-07-25 · Accepted · `4c7f109`**

Grafana speaks Telegram natively, so there is no n8n hop, no self-hosted relay, and
nothing extra to keep alive in order to find out that something died. ntfy was considered
and rejected: it would be one more service to run, on the infrastructure being monitored.

The bot is **Den Den Mushi** — the transponder snail carries messages. The name is
reserved for the bot, not a machine.

**Consequence:** the contact point and notification policy tree are provisioned as code
and therefore read-only in the Grafana UI. `repeat_interval` is 24h: frequent enough not
to forget, rare enough not to learn to ignore. Komodo alerts to Discord separately and
the two overlap — some alerts arrive twice, nobody has narrowed either side.
