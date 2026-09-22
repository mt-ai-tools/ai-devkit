---
enforce: [before-finishing]
summary: A failure seen once is a symptom, not a finding. Reproduce it alone before naming a cause.
---

# Reproduce before reporting

A failure seen once is a symptom. What it was caused by is a claim, and a
claim is reproduced before it is made.

- Reproduce it on its own before naming a cause. Alone means away from
  whatever else was happening: the one part, the one call, nothing else
  moving.
- Where it will not reproduce, say what was seen and that it did not
  repeat — and name nothing as the reason. An unreproduced failure is
  worth reporting; the guess about it is not.
- Whatever else might have been moving belongs in the report, not in the
  correction afterwards. A reader deciding what to do needs to know the
  ground was uncertain, and learns nothing from being told later.
- This binds a claim about the tools exactly as it binds one about the
  code. "The checker is broken" is a finding like any other, and the
  easiest one to reach for when a check refuses.
- The cost is asymmetric, which is why this is a rule rather than
  taste. A finding that waits for a second look costs minutes. A wrong
  one is acted on: work planned around it, a fix written for it, and the
  real fault still there afterwards.

Related:
- [odd-means-unfinished](odd-means-unfinished.md) — what to do with a finding once it holds.
- [short-answers](short-answers.md) — how it is said once it does.
