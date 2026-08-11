# actual-rules-mining

## Spec

Find payees the ported rules still miss and propose native Actual rules for them, monthly.
Stage 2 of three. Starts after [actual-rules-port](actual-rules-port.md) lands, which is
what defines "still miss".

Done when a monthly run proposes only payees no existing rule covers, and a run whose
candidates are all `auto: LLM`-derived proposes nothing.

## Design

Same sidecar and same approval node as the port. Budget sync IDs in
[REFERENCE.md](../REFERENCE.md).

| Step | Contract |
|---|---|
| Group | AQL over LE MILLION: group by payee, keep payees whose transactions all land in one category, above a minimum count |
| Exclude rules | Drop payees an existing rule already covers |
| Exclude LLM | Drop anything whose note carries the `auto: LLM` marker from [actual-llm-categorization](actual-llm-categorization.md) |
| Cap | Top 10 by transaction count. The rest returns next month |
| Approve | `sendAndWait`, `chatApproval: true`, `approverIds` set. Condition, action, match counts, overlapping rules |
| Write | `POST /rules` on approval only |

The LLM exclusion is load-bearing, not hygiene. Stage 3 writes categories the model guessed;
without the filter, a guess that clears the confidence bar a few times reads here as "this
payee always lands in this category" and becomes a permanent native rule. The approval
message looks identical either way, so the human gate does not catch it.

Verify: seed a payee with `auto: LLM` notes only, run, confirm it is not proposed.
