# Komodo + Compose, not Kubernetes

**2026-07-18 · Accepted · `bb0aabb`**

The fleet is four heterogeneous machines: an ARM cloud VM, an OpenVZ VPS on a
provider-controlled 4.19 kernel, a managed seedbox with no root, and a Raspberry Pi.
Kubernetes needs a homogeneous, controllable substrate that none of them offer, and
its operational surface dwarfs the workload.

Komodo drives plain Compose stacks from this repo over the mesh: one web UI across
every Docker node, GitOps from git, no control-plane of its own to babysit.

**Consequence:** everything is a `compose.yaml` plus a `[[stack]]` entry. No
orchestration primitives — no rescheduling, no self-healing beyond
`restart: unless-stopped`, no rolling deploys. Accepted; the fleet is two Docker nodes.
