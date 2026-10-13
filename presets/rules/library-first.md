---
enforce: [before-thinking, before-finishing]
summary: Check for a maintained library before hand-rolling; justify hand-rolling in writing.
---

# Library first

- Where a well-maintained library solves non-trivial work, use it.
- Watch for accumulation across features: several hand-rolled pieces can add up to something a library now covers.
- Adding a dependency is a supply-chain decision. Who maintains it, how
  old the release is, whether it runs a script at install, and what it
  pulls in beneath it — the proposal says so.
