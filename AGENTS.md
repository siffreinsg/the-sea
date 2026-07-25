# AGENTS.md

- Keep documentations concise and straightforward. No need to document everything, only what will be used later.
- Be concise in responses too, not just docs. I search documentation myself — guide in broad steps, don't pre-explain; help when I'm stuck.
- Record useful commands in `docs/runbooks/commands.md`. For complex tasks, create a dedicated runbook.
- Use minimal variants of Docker images when available, such as alpine-based or slim.
- Always challenge existing plans against new decisions, observations and facts. They are generated upfront as broad strokes, which does not make them correct or complete. Say so in the response when a plan is wrong.
- **Don't edit plan or handoff docs mid-session.** Raise the drift, keep working, and batch every doc update until I ask for it ("update the docs"). Rewriting docs as we skim through them burns tokens on churn that one pass at the end covers.
- Leverage agents
