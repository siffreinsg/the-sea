# The Thousand Sunny stays off the mesh

**2026-07-25 · Accepted · `3a39e61`**

Sunny is an Ultra.cc box with no root and no Docker. Adding a userspace Tailscale client
was assumed necessary for a long time — it was even a blocking task on the Bazarr plan.

It isn't. Every service Sunny runs is already publicly reachable over HTTPS, and its
SSH/SFTP answers on port 22 from GM. Nothing about the current integrations needs mesh
membership.

**Consequence:** the Bazarr plan's blocking "Task 0" was deleted outright. The one case
that would justify revisiting is shipping Sunny's own logs and metrics to the
observability stack, which binds a mesh-only address — tracked in
[future](../future.md).
