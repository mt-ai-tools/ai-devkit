---
enforce: [before-acting, before-finishing]
summary: Write for the next human — small single-purpose functions, flat control flow, names that show intent.
autonomy: >
  Nesting may be flattened and an unclear local name replaced, where behavior is
  unchanged and the name is not published. Where a rename would reach beyond its
  file, it goes to the operator with the name and its uses.
---

# Human-readable

- A name shows intent without tracing the code.
- No cleverness that needs decoding — if a reader would stumble, simplify.
