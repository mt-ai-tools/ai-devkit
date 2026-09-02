---
enforce: [before-acting, before-finishing]
summary: Comments explain why, not what — constraints, trade-offs, and risks a future reader would wonder about.
autonomy: >
  A missing or restating comment may be fixed where the reason is evident from
  the code, its tests, or the commit that introduced it. Where the why would
  have to be guessed, it goes to the operator with the line and what could not
  be established about it.
---

# Comment the why

Comments explain why, not what. The code already says what.

- Comment hidden constraints, trade-offs, invariants, or a fix for a specific bug.
- If changing or removing something carries a non-obvious risk you know today — a guard, exception, threshold, constant, or ordering —
  comment the risk, so a future reader can judge whether it's safe to touch.
- Don't restate what the code plainly does.
- Use why-comments freely. The bar: would a future reader wonder *why* this was done, or whether it's *safe to delete or change*? If yes, add one line.
- One line is almost always enough. No code-restating docblocks.
