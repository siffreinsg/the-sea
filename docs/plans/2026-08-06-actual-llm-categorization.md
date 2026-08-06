# Plan — LLM categorization of leftover transactions

Stage 3 of three. Categorizes what the rules do not catch, including the backlog rules
cannot reach retroactively. Chains onto the existing bank-sync workflow. Delete this doc
when it lands.

## Blocked on one test — do this first

n8n reaches LiteLLM at `https://ai.siffreinsigy.me`, which means leaving the box and coming
back through hairpin NAT. That is unproven here, and the audit item in [TODO](../TODO.md)
about hairpin NAT is the same doubt.

```
docker exec n8n wget -qO- --timeout=5 https://ai.siffreinsigy.me/health/liveliness
```

If it fails, the fallback is `host.docker.internal:4000` — LiteLLM publishes
`127.0.0.1:4000` and n8n already uses that hostname for its OTEL export. Do not build the
rest of this plan until one of the two answers.

## LiteLLM key

A dedicated virtual key for this workflow, `max_budget` and `budget_duration` set **at
creation**, not added later. Lands the "wire n8n to LiteLLM" bullet in
[FUTURE](../FUTURE.md), which is deleted in the same commit.

## Workflow — appended to the bank-sync workflow

1. AQL for uncategorized transactions in LE MILLION.
2. **One** LLM call carrying the category list and every uncategorized transaction, not one
   call per transaction. Returns `[{id, category, confidence}]`. Keeps this to roughly two
   requests a day, far under the 240/min/service Caddy rate limit.
3. Above the confidence threshold: `PATCH /transactions/{id}` with the category **and a note
   carrying the `auto: LLM` marker**. [Stage 2](2026-08-06-actual-rules-mining.md) reads that
   marker to keep model guesses out of mined history — it is not decoration.
4. Below the threshold: one Telegram message listing them, no writes.

Self-reported confidence is not a calibrated probability and the threshold will need tuning
against real output. The marker is what makes that safe to get wrong: every automated write
stays greppable in Actual and reversible in bulk.

## Done when

A sync leaves no uncategorized transaction unhandled — each one either carries a category
with an `auto: LLM` note, or appears in the low-confidence Telegram list.
