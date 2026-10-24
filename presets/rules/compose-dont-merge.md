---
enforce: [before-finishing]
summary: Keep each concern in its own file, combined by a thin orchestrator that holds no concern's logic.
---

# Compose, don't merge

- The orchestrator only wires and sequences.
- Each concern stays a standalone, single-purpose file, testable alone.
- "They always run together" is a reason to orchestrate, not to merge.
