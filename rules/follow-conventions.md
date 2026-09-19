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
- An entry holds a convention the project settled, nothing more: one
  that many modules could break, stated as what must hold rather than
  how the code does it today. A fact about one module's workings is a
  why-comment beside that code, and what the code does today is read
  off the code.
- An entry stays while its convention does. A check that enforces it —
  a type, a test, a lint rule — is how it is kept today, not where it
  lives: checks are loosened and lost, and only the entry says the
  check was right.
- Where nothing is written, match the surrounding code.
- If you had to infer a convention — or just helped establish one —
  propose recording it as an entry, where it meets the bar above. The
  collection grows from exactly these moments.
- This rule names no specific collection — each project declares its
  own home for one.

Related:
- [propose-dont-decide](propose-dont-decide.md) — adopting a new convention is the operator's call.
- [single-source-of-truth](single-source-of-truth.md) — the entry is the convention's one home.
