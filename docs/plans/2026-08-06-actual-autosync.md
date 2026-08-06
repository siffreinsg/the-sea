# Plan — Actual Budget auto-sync

Twice-daily GoCardless bank sync, driven by n8n. Delete this doc when it lands.

Actual has no scheduled sync ([upstream #3831](https://github.com/actualbudget/actual/issues/3831))
and no REST API — only the `@actual-app/api` Node library, whose `runBankSync({accountId})`
does the work. So n8n needs an HTTP surface in front of that library:
[ADR](../ADR/2026-08-06-n8n-drives-actual-via-http-sidecar.md).

## Sidecar

Add `actual_api` to `thriller-bark/actualbudget/compose.yaml`.

- Image `jhonderson/actual-http-api:26.7.0`. Its tags mirror Actual's own version —
  **bump it in the same commit as `actual_server`**, the library applies migrations to the
  budget file and a version behind the server fails at `downloadBudget`, i.e. on every
  endpoint. Renovate sees both.
- Networks `default` (reach `actual_server:5006`) and `n8n-edge` (reachable from n8n).
  No published port, not behind Caddy.
- `ACTUAL_SERVER_URL=http://actual_server:5006/`. `API_KEY` and `ACTUAL_SERVER_PASSWORD`
  from `secrets.env` — the stack has none today, so it gains a
  `pre_deploy.command = "umask 077 && sops -d secrets.env > .env"` row in
  `komodo/resources.toml`. `.gitignore`'s bare `.env` and `.sops.yaml`'s catch-all already
  cover it; no new entry in either.
- Named volume on `/data` (`ACTUAL_DATA_DIR`, from the image's Dockerfile). Budget **cache**
  only — the budget of record is `actual-data`, so this stays out of `backup.sh`.

## Workflow

Built in the n8n UI, lives in the n8n volume (already in `n8n/backup.sh`).

Schedule 06:00 and 18:00 Europe/Paris → HTTP Request → error branch → Telegram.

- `POST http://actual_api:5007/v1/budgets/322d8514-c9fc-4574-8ef3-131dbbe63bd7/accounts/banksync`
  (no `accountId` = every linked account), `x-api-key` from an n8n credential.
- Twice daily stays inside GoCardless's 4 requests/day/account free-tier cap.
- The route awaits `runBankSync` inside its `try`, so a failure — including the 90-day
  consent expiry, which *will* fire — surfaces as a 500 and reaches Telegram. No extra
  health check needed.

## Docs riding the commits

- ADR, plus its row in [ADR/README.md](../ADR/README.md)
- `thriller-bark/n8n/compose.yaml` — the `n8n-edge` comment says "shared only with Caddy",
  no longer true
- [REFERENCE](../REFERENCE.md) — `n8n-edge` membership row, schedule
- [FUTURE](../FUTURE.md) — split the Actual bullet, auto-sync moves to TODO, the other three stay

## Deliberately not built

Transaction-count reporting and a weekly heartbeat. Add them if a silent no-op ever bites.

## Done when

The workflow is triggered by hand and new transactions appear in the Actual UI. A 200 from
the endpoint is not the check.
