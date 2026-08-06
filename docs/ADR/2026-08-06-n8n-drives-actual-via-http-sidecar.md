# n8n drives Actual through an HTTP sidecar

**2026-08-06 · Accepted**

Actual has no REST API and no scheduled sync, only the `@actual-app/api` Node library.
Loading that library in an n8n Code node needs a custom n8n image, `NODE_FUNCTION_ALLOW_EXTERNAL`
and a budget cache on n8n's volume — a rebuild on every n8n bump. A `jhonderson/actual-http-api`
sidecar in the actualbudget stack turns the library into an HTTP surface n8n can call by
container name, and the same surface serves the categorization, rules and Telegram
automations in [FUTURE](../FUTURE.md). A sync-only container was rejected for that reason:
it buys the first automation and blocks the other three.

Consequences:

- `n8n-edge` gains a second member. The sidecar is a fixed API surface, not a proxy, and
  n8n is no router — a workflow still reaches nothing on `edge`.
- The sidecar's tag mirrors Actual's version and must be bumped with `actual_server`. An
  older api lib fails at `downloadBudget`, so on every endpoint.
- Anything holding the sidecar's `API_KEY` has full read/write on the budget. It is never
  published or proxied.
