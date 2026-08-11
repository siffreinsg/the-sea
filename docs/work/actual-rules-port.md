# actual-rules-port

## Spec

Copy the rule set built by experiment in the `Road to a million` budget into the live
`LE MILLION` budget, one Telegram approval per rule. Stage 1 of three; stage 2 is
[actual-rules-mining](actual-rules-mining.md).

Done when every candidate has been approved or rejected, the closing report lists what was
skipped and why, and an approved rule fires on the next bank sync.

## Design

Everything goes through the `actual_api` sidecar
([ADR](../ADR/2026-08-06-n8n-drives-actual-via-http-sidecar.md)). Sync IDs and the source
budget's encrypted flag are in [REFERENCE.md](../REFERENCE.md).

| Piece | Contract |
|---|---|
| Secret | `ACTUAL_SOURCE_BUDGET_PASSWORD` in `thriller-bark/actualbudget/secrets.env`, sent as the `budget-encryption-password` header on every source call. Stored, not prompted: the sidecar needs it again after a restart |
| Read | `GET /rules` on source; `GET /categories` + `GET /payees` on both |
| Remap | Rewrite category and payee references **by name**. IDs do not survive across budgets |
| Filter | Drop candidates already in the target, or with no category/payee counterpart. Both lists go in the report |
| Score | One AQL count per survivor: transactions matched, and how many are uncategorized |
| Approve | Telegram `sendAndWait`, `chatApproval: true`, `approverIds` set. Message carries condition, action, both counts, any overlapping rule |
| Write | `POST /rules` on approval only |

**Cap 10 candidates per run.** `sendAndWait` blocks per item, so an uncapped run queues every
remaining rule behind one waiting out its 45-minute limit. Manual trigger, rerun until empty.

Blocking unknown: the source budget reports `hasKey: false`. Confirm the sidecar opens it
with the password header before building anything else.

Verify: an approved rule categorizes a matching transaction on the next sync.
