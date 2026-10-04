---
enforce: [before-acting, before-finishing]
summary: Write for the next human — small single-purpose functions, flat control flow, names that show intent.
autonomy: >
  Nesting may be flattened and an unclear local name replaced, where behavior is
  unchanged and the name is not published. Where a rename would reach beyond its
  file, it goes to the operator with the name and its uses.
---

# Human-readable

Write code for the human who reads it next, not the one writing it now.

- Small, single-purpose functions; prefer flat control flow over deep nesting.
- Name so intent is clear without tracing the code.
- No cleverness that needs decoding — if a reader would stumble, simplify.
- Put a comment directly above what it explains.

Related:
- [comment-the-why](comment-the-why.md) — what a comment should say.
- [split-at-seams](split-at-seams.md) — the same principle at file scale.
