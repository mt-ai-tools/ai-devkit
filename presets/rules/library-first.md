---
enforce: [before-thinking, before-finishing]
work: [shape, talk]
summary: Find the industry's standard way and any maintained library before shaping anything; justify departing from either in writing.
---

# Library first

- Before shaping a mechanism, find how established frameworks and services solve it, and offer that way first; a departure names what the standard way fails.
- Where a well-maintained library solves non-trivial work, use it.
- Watch for accumulation across features: several hand-rolled pieces can add up to something a library now covers.
- Adding a dependency is a supply-chain decision. Who maintains it, how
  old the release is, whether it runs a script at install, and what it
  pulls in beneath it — the proposal says so.
