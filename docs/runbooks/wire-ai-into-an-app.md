# Wire a new consumer to LiteLLM

How any app on the fleet gets an OpenAI-compatible AI backend. LiteLLM is the only
gateway — nothing dials Scaleway or Mistral directly.

## 1. Base URL

- **On `the-sea-internal`** (TB container, same Docker network as `litellm`):
  `http://litellm:4000/v1`
- **Off-network** (GM, or anything not on `the-sea-internal`): `https://ai.siffreinsigy.me/v1`
  — public edge, protected by the virtual key alone, no forward_auth
  ([why](../../thriller-bark/caddy/Caddyfile) — see the `@litellm` block).

## 2. Generate a virtual key, budgeted at creation

Never a follow-up patch — a runaway consumer must not exhaust another one's budget.

```
curl -s -X POST http://127.0.0.1:4000/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H 'Content-Type: application/json' \
  -d '{"max_budget":10,"budget_duration":"30d"}'
```

Current keys: Open-WebUI €30, n8n €10, Karakeep €5, all `30d`. The `max_budget: 50` /
`budget_duration: 30d` in `litellm_settings` (`config.yaml`) is only the global backstop,
not a substitute.

## 3. Wire the app

Point the app's own "OpenAI API" settings at the base URL from step 1 and the key from
step 2 — `OPENAI_API_BASE_URL` / `OPENAI_API_KEY` or equivalent, key in that app's
`secrets.env`, never the master key. Model names come from `thriller-bark/litellm/config.yaml`'s
`model_list`, not from the provider's own naming.

## 4. Verify

```
curl -s https://ai.siffreinsigy.me/v1/models -H "Authorization: Bearer sk-..."
```
Then a real request from inside the app. Confirm the spend log shows the app's key, not
the master key.
