---
enforce: [before-thinking, before-finishing]
summary: Dependencies run one way, features meet at published interfaces, and nothing forms a cycle.
---

# Respect boundaries

Keep layers and features separate. No reaching across.

- Dependencies run one way: a module uses what sits below it, never what sits
  above. Which is below is evident from what each module is for — it needs no
  declaring.
- No cross-layer imports (e.g. a presentation layer importing server internals).
- No cross-feature imports — features talk through shared, declared interfaces, not each other's internals.
- No import cycles. A cycle says something sits in the wrong module; it is not
  a graph that needs an exception.

Related:
- [keep-modules-independent](keep-modules-independent.md) — its behavioral sibling: fix a problem where it lives.
