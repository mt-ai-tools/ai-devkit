---
enforce: [before-thinking, before-finishing]
summary: Dependencies run one way, features meet at published interfaces, nothing forms a cycle.
---

# Respect boundaries

Keep layers and features separate. No reaching across.

- A module uses what sits below it, never what sits above. Which is below
  is evident from what each module is for — it needs no declaring.
- No cross-layer imports.
- No cross-feature imports — features talk through shared, declared interfaces, not each other's internals.
- A cycle says something sits in the wrong module.
- Time is a boundary too. What runs in production never depends on what
  exists only to build, test, or deploy it — those sit above it. A
  decision the running code must make is never taken from a module that
  stops existing once it is deployed.
