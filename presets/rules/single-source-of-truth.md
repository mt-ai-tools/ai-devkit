---
enforce: [premise, before-finishing]
summary: Every fact lives in exactly one place. Reference it, never copy it.
autonomy: >
  A copy may be deleted where the finding names which one is the source. Where
  either could be, it goes to the operator with both places and what each holds.
  A literal in a test that ship-tests says to spell is not a copy and not a
  finding here.
---

# Single source of truth

*A premise several other rules rest on.*

Every fact lives in exactly one place. Reference it; never copy it.

- A value, definition, type, schema, or piece of knowledge has one home. Everything else points to it.
- Don't restate the same fact in two places — the copies drift.
- What counts as one fact is decided by who reads it. Where several
  tools each resolve a thing by a name of their own, each name is that
  tool's fact, and their differing is not a copy drifting. A copy is
  one reader's fact held twice.
- Docs describe their own concern only — not file contents, file lists, or outside state (repo status, inventory, what else exists). That drifts; point instead.
- When you catch yourself copying, stop: extract the source and reference it.
