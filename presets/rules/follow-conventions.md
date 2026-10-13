---
enforce: [before-thinking, before-finishing]
summary: Follow the written conventions, else the surrounding code; propose recording what you had to infer.
---

# Follow conventions

- Find the project's conventions collection before shaping new code, and
  follow what it says.
- Entries are normative, as the rules are: code conforms to them, never
  the other way around. Code that disagrees with one is wrong, however
  old — point it out, never copy it as the house style. A comment in the
  code describes the code; it is never an entry or a rule.
- An entry holds a convention the project settled, nothing more: one
  that many modules could break, stated as what must hold rather than
  how the code does it today. A fact about one module's workings is a
  why-comment beside that code.
- An entry that would need rewriting when a library, a protocol or a
  number changes holds mechanism, not convention, and the mechanism is a
  why-comment where it lives. A unit, a count, a field name, a library
  or a protocol in the sentence is the tell.
- An entry forbids something a contributor might otherwise reasonably
  do. One that forbids nothing is describing a habit.
- An entry stays while its convention does. A check that enforces it
  never replaces it: checks are loosened and lost, and only the entry
  says the check was right.
- Where nothing is written, match the surrounding code.
- If you had to infer a convention — or just helped establish one —
  propose recording it as an entry, where it meets the bar above. The
  proposal is the entry's exact final text, one demand per line, each line
  already held to that bar; a line naming how the code does it is struck
  before it is shown.
