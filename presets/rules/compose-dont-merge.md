---
enforce: [before-finishing]
summary: Keep each concern in its own file, combined by a thin orchestrator that holds no concern's logic.
autonomy: >
  A concern may be lifted out of an orchestrator into a sibling file, where the
  finding names the concern. Where what counts as one concern is arguable, it
  goes to the operator with what it would separate.
---

# Compose, don't merge

- The orchestrator only wires and sequences.
- Each concern stays a standalone, single-purpose file, testable alone.
- "They always run together" is a reason to orchestrate, not to merge.
