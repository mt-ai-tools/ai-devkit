---
enforce: [premise]
summary: Assume everything grows and gets reused elsewhere. Set the right shape now, while it is cheap.
---

# Design for growth

*A premise several other rules rest on.*

Assume every project, feature, file, and function will grow, and that something you did not plan for will want to use it. Build for the bigger version, not today's size.

- Today's small piece is tomorrow's larger one. Plan for it; don't be surprised by it.
- Prefer the structure that stays clean as it grows — split, extend, name for a future reader.
- Assume reuse. Write every piece as if a project you have not met will depend on it: no assumptions about its surroundings, nothing baked in that only makes sense here.
- "It's only small / one caller / one use case right now" is not a reason to cut corners. It's the reason to set the shape correctly now, while it's cheap.
