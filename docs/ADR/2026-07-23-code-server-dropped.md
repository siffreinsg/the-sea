# Code-Server is dropped, not deferred

**2026-07-23 · Accepted · `c1284f1`**

Code-Server was in the batch-1 plan, carried over from the pre-Komodo GM stack. It is a
browser-reachable arbitrary-code-execution surface on a node that also holds application
data, and the value over an SSH session from a real editor is small.

**Consequence:** it is not in `FUTURE.md` and should not come back through the wishlist.
Its legacy data dir on GM is preserved but will not be redeployed. If a browser editor is
ever wanted, SilverBullet over a synced folder is the shape to reach for, not a full IDE.
