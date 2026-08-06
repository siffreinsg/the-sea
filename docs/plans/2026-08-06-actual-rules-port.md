# Plan — port Actual rules from the encrypted budget

Stage 1 of three. Copies the rule set built by experiment in `Road to a million` into the
live budget, one Telegram approval per rule. Delete this doc when it lands.

Everything runs through the `actual_api` sidecar
([ADR](../ADR/2026-08-06-n8n-drives-actual-via-http-sidecar.md)).

| Budget | Sync ID | Encrypted |
|---|---|---|
| LE MILLION (live, target) | `322d8514-c9fc-4574-8ef3-131dbbe63bd7` | no |
| Road to a million (source) | `1eec67e9-8afc-4419-a4d4-9be2007edece` | **yes** |

## Secret

The source budget's encryption password joins `thriller-bark/actualbudget/secrets.env` as
`ACTUAL_SOURCE_BUDGET_PASSWORD`, passed as the `budget-encryption-password` header on every
call against it. The sidecar may need it again after a restart, so it is a stored secret,
not a one-off prompt. `.gitignore` and `.sops.yaml` already cover the file.

## Workflow — manual trigger, run repeatedly until the candidate list is empty

1. `GET /rules` on the source; `GET /categories` and `GET /payees` on **both** budgets.
2. Rewrite each rule's category and payee IDs **by name**. IDs do not survive across
   budgets, so a copied ID silently points at nothing or, worse, at a different category.
3. Drop candidates that are already present in the target, or whose category/payee has no
   counterpart there. Both lists go in the closing report rather than being silently eaten.
4. For each surviving candidate, one AQL count against the target: how many transactions it
   would match, and how many of those are currently uncategorized.
5. **Cap at 10 per run.** `sendAndWait` blocks per item, so an uncapped first run queues
   every remaining rule behind the one waiting at its 45-minute limit.
6. Telegram `sendAndWait`, `chatApproval: true`, `approverIds` set to the one approver.
   Each message carries the condition, the action, the two counts from step 4, and any
   overlapping existing rule.
7. `POST /rules` on approval only.

## Traps

- Actual applies rules **on import**, so approving a rule does not categorize the existing
  backlog. Stage 3 clears that. Verify against 26.8 before writing the report copy — if a
  bulk re-apply does exist, this plan should call it and stage 3 shrinks.
- The source budget reports `hasKey: false`. Confirm the sidecar accepts the password header
  and can open it before building anything else; this whole plan is blocked on that one call.

## Done when

Every candidate has been approved or rejected, the report lists what was skipped and why,
and a rule that was approved fires on the next bank sync.
