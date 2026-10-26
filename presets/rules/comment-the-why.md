---
enforce: [before-acting, before-finishing]
summary: Comments explain why, not what — constraints, trade-offs, and risks a future reader would wonder about.
---

# Comment the why

- Comment hidden constraints, trade-offs, invariants, or a fix for a specific bug.
- If changing or removing something carries a non-obvious risk you know today,
  comment the risk, so a future reader can judge whether it's safe to touch.
- Where a tempting alternative was tried or rejected, say which one and what
  it broke, so nobody walks back into the same hole.
- Use them freely: wherever a future reader would wonder *why* this was done,
  or whether it's *safe to delete or change*.
- A comment sits directly above what it explains.
- One line is almost always enough. No code-restating docblocks.
- One sentence above an export may say what it is for, on one line: no
  parameter restated, no usage example.
