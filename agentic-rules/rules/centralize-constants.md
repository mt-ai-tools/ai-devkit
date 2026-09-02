---
enforce: [before-acting, before-finishing]
summary: No inline magic values. Name every constant, limit, and config value in one place, then import it.
autonomy: >
  A literal may be moved to a named constant, and the name invented where none
  exists yet, placed among the constants it belongs beside. Naming a value the
  code already uses is reading, not deciding. Where it would need a home that
  does not exist, the structural fence holds and it goes to the operator. A
  literal in a test that ship-tests says to spell is not a finding here.
---

# Centralize constants

No inline magic values. Name every constant, limit, and config value in one place.

- No bare numbers or literals for limits, sizes, counts, timeouts, or quotas in logic.
- Define them as named constants in a dedicated module, then import.
- Read all configuration through one loader — don't scatter env/config reads across files.
- This applies at every layer.

Related:
- [single-source-of-truth](single-source-of-truth.md) — its premise; constants and config have one home.
- [propose-dont-decide](propose-dont-decide.md) — a constant needing a home that does not exist yet is a shape, and the shape is the operator's.
