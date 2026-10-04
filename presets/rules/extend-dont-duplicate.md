---
enforce: [before-thinking, before-finishing]
summary: When a shared abstraction almost fits, extend it. Never fork or copy it.
---

# Extend, don't duplicate

When a shared abstraction almost fits, extend it. Never fork or copy it.

- Need a new capability from a shared component, hook, or utility? Add a parameter or option to it.
- Never copy an implementation to tweak one detail. Duplicates diverge and multiply maintenance.
- "Only one use case right now" is a reason to extend cleanly, not to duplicate.
- Before writing something new, check whether a shared version already exists.
- When the right extension point is unclear, stop and flag it before writing code.

Related:
- [single-source-of-truth](single-source-of-truth.md) — its premise; behavior has one home.
- [design-for-growth](design-for-growth.md) — the second use case is coming; extend now.
- [propose-dont-decide](propose-dont-decide.md) — the extension point is the operator's call.
