---
enforce: [before-acting, before-finishing]
summary: No inline magic values. Name every constant, limit, and config value in one place.
---

# Centralize constants

- No bare numbers or literals for limits, sizes, counts, timeouts, or quotas in logic.
- Each has one named home that every use refers to.
- Read all configuration through one loader.
- A literal in a test that ship-tests says to spell is not a finding here.
