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

The source budget's encryption password is **header-only** — `src/config/config.js` loads
just `API_KEY` and `ACTUAL_SERVER_PASSWORD`, so there is nothing to put in `secrets.env`.
It lives in n8n as an `httpCustomAuth` credential, which is the one generic credential type
that carries two headers at once (`x-api-key` and `budget-encryption-password`). Calls
against the target budget keep the existing `httpHeaderAuth` credential.

## Workflow — manual trigger, run repeatedly until the candidate list is empty

1. `GET /rules` on the source; `GET /categories` and `GET /payees` on **both** budgets.
2. Rewrite each rule's category and payee IDs **by name**. IDs do not survive across
   budgets, so a copied ID silently points at nothing or, worse, at a different category.
3. Drop candidates whose category or payee has no counterpart in the target; they go in the
   closing report rather than being silently eaten. No dedup against existing target rules
   beyond a cheap string similarity note on the approval message — comparing rule objects
   means normalizing nested arrays, and a duplicate rule in Actual is harmless anyway.
4. For each surviving candidate, one `run-query` count against the target. Only for
   conditions that translate to a query filter directly — a general count means
   reimplementing Actual's rule matcher, which is not worth it. Conditions that don't
   translate are shown without a count rather than with a guessed one.
5. **Cap at 10 per run.** `sendAndWait` blocks per item, so an uncapped first run queues
   every remaining rule behind the one waiting at its 45-minute limit.
6. Telegram `sendAndWait`, `chatApproval: true`, `approverIds` set to the one approver,
   `limitWaitTime` in days. The 45-minute default expires while you are still reading
   candidate 1. **Confirm what the node emits on timeout before wiring the create step** —
   if an expiry resumes on the normal output, it creates rules nobody approved, which is
   the one failure this gate exists to prevent.
7. `POST /rules` on approval only. Strip the source `id` from the body; a spread carries it
   through. Keep `stage` and `conditionsOp`, both required.

## Traps

- Actual applies rules **on import**, so approving a rule does not categorize the existing
  backlog. Stage 3 clears that. Verify against 26.8 before writing the report copy — if a
  bulk re-apply does exist, this plan should call it and stage 3 shrinks.
- The source budget reports `hasKey: false`. Confirm the sidecar accepts the password header
  and can open it before building anything else; this whole plan is blocked on that one call.

## Done when

Every candidate has been approved or rejected, the report lists what was skipped and why,
and a rule that was approved fires on the next bank sync.
