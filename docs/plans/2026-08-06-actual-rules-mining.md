# Plan — mine Actual rules from history

Stage 2 of three. Finds payees the ported rules still miss and proposes rules for them.
Starts after [the port](2026-08-06-actual-rules-port.md) lands, which is what defines
"still miss". Delete this doc when it lands.

## Workflow — monthly

1. AQL over LE MILLION: group transactions by payee, keep payees whose transactions all
   land in one category, above a minimum count.
2. Drop payees already covered by an existing rule.
3. **Drop anything whose note carries the `auto: LLM` marker written by
   [stage 3](2026-08-06-actual-llm-categorization.md).** Load-bearing, see below.
4. Cap at the top 10 by transaction count. Whatever is left comes back next month.
5. Same approval node and message shape as the port: condition, action, match counts,
   overlapping rules. `sendAndWait`, `chatApproval: true`, `approverIds` set.
6. `POST /rules` on approval only.

## Why step 3 exists

Stage 3 writes categories the model guessed. Without the exclusion, a guess that clears the
confidence bar a few times reads here as "this payee always lands in this category" — and
becomes a permanent native rule. The approval message would look identical whether a human
or the model categorized those transactions, so the human gate does not catch it. The marker
is the only thing that keeps mined history human-authored.

## Done when

A monthly run proposes only payees that no existing rule covers, and a run whose candidates
are all `auto: LLM`-derived proposes nothing.
