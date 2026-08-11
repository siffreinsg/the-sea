# actual-llm-categorization

## Spec

Categorize the transactions rules do not catch, including the backlog rules cannot reach:
Actual applies rules on import, so approving a rule never touches existing transactions.
Stage 3 of three. Chains onto the existing bank-sync workflow.

Done when a sync leaves no uncategorized transaction unhandled — each one either carries a
category with an `auto: LLM` note, or appears in the low-confidence Telegram list.

## Design

**Blocked on one test.** n8n reaches LiteLLM at `https://ai.siffreinsigy.me`, which leaves
the box and returns through hairpin NAT. Unproven, and the same doubt as the edge-scan item
in [TODO.md](../TODO.md). Build nothing until this answers:

```
docker exec n8n wget -qO- --timeout=5 https://ai.siffreinsigy.me/health/liveliness
```

On failure, fall back to `host.docker.internal:4000` — LiteLLM publishes `127.0.0.1:4000`
and n8n already uses that hostname for its OTEL export.

| Step | Contract |
|---|---|
| Key | A dedicated LiteLLM virtual key, `max_budget` and `budget_duration` set at creation |
| Read | AQL for uncategorized transactions in LE MILLION |
| Infer | **One** call carrying the category list and every uncategorized transaction, not one per transaction. Returns `[{id, category, confidence}]`. Roughly two requests a day, far under Caddy's 240/min/service limit |
| Write | Above threshold: `PATCH /transactions/{id}` with the category and a note carrying the `auto: LLM` marker |
| Defer | Below threshold: one Telegram message listing them, no writes |

Self-reported confidence is not calibrated; the threshold needs tuning against real output.
The marker is what makes getting it wrong safe — every automated write stays greppable in
Actual and reversible in bulk.

Verify: `wget` above returns, then a dry run lists uncategorized transactions with scores.
