---
enforce: [before-thinking, before-finishing]
summary: Follow established conventions — written ones from the project's conventions collection, unwritten ones from surrounding code; propose recording what you had to infer.
---

# Follow conventions

The project's established conventions are followed, not rediscovered
or reinvented.

- Written conventions live in the project's conventions collection — a
  directory of one-file-per-convention entries. Find it before shaping
  new code, and follow what it says.
- Entries are normative: code conforms to the entry, never the other
  way around. Code that disagrees with an entry is wrong, however old.
- Where nothing is written, match the surrounding code.
- If you had to infer a convention — or just helped establish one —
  propose recording it as an entry. The collection grows from exactly
  these moments.
- This rule names no specific collection — each project declares its
  own home for one.

Related:
- [propose-dont-decide](propose-dont-decide.md) — adopting a new convention is the operator's call.
- [single-source-of-truth](single-source-of-truth.md) — the entry is the convention's one home.
