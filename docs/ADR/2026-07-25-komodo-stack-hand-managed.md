# The komodo stack is not managed by Komodo

**2026-07-25 · Accepted · `0357d38`**

Every stack in the fleet is deployed by Komodo from this repo. The control plane itself
cannot be, without Core redeploying the container performing the deploy — a bootstrap
hazard worse than the inconsistency it would fix.

`komodo` is the one stack with no `[[stack]]` entry. It runs from `/opt/the-sea/thriller-bark/komodo/`,
a user-owned checkout, updated by hand.

**Consequence:** that checkout drifts silently, and `resources.toml` changes never reach
it — including the `umask 077` every other stack gets from its `pre_deploy` hook. The
procedure, and the three traps that come with it, are in [deploy](../domains/deploy.md).
Its images are pinned precisely because nothing else guards this path.
