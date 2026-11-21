---
enforce: [before-acting, before-finishing]
work: [write]
summary: Comments explain why, not what — only where a reader would otherwise misread the code or change it unsafely.
---

# Comment the why

- Comment only where a reader would otherwise misread the code or change
  it unsafely.
- That is: a hidden constraint, trade-off or invariant; a fix for a
  specific bug; what is non-standard or ambiguous; why a number is what
  it is; an outside library's quirk.
- If changing or removing something carries a non-obvious risk you know today,
  comment the risk, so a future reader can judge whether it's safe to touch.
- Where a tempting alternative was tried or rejected, say which one and what
  it broke, so nobody walks back into the same hole.
- A comment sits directly above what it explains.
- A comment or doc says only what holds where it sits; how another place
  works is that place's to say, and it points there by role.
- One line is almost always enough. No code-restating docblocks.
- One sentence above an export may say what it is for, on one line: no
  parameter restated, no usage example.
