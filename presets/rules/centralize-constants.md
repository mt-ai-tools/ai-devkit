---
enforce: [before-acting, before-finishing]
summary: No inline magic values. Name every constant, limit, and config value in one place.
autonomy: >
  A literal may be moved to a named constant, and the name invented where none
  exists yet. Naming a value the code already uses is reading, not deciding.
  Where it would need a home that does not exist, it goes to the operator. A
  literal in a test that ship-tests says to spell is not a finding here.
---

# Centralize constants

- No bare numbers or literals for limits, sizes, counts, timeouts, or quotas in logic.
- Each has one named home that every use refers to.
- Read all configuration through one loader.
