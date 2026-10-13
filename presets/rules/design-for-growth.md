---
enforce: [premise]
summary: Assume everything grows and gets reused; set the right shape now, while it is cheap.
---

# Design for growth

- Build for the bigger version, not today's size, in the structure that
  stays clean as it grows.
- Assume nothing about a piece's surroundings, and bake in nothing that
  only makes sense here.
- "It's only small / one caller / one use case right now" is not a reason to cut corners.
- Build for the scale the project declares, done fully: every security hole closed, every case a user or an attacker can reach handled. Never build past that scale before something real grows there.
