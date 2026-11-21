---
enforce: [before-finishing]
work: [write, talk]
summary: A convention entry is the most general shape the project settled, stated as what must hold, never how the code does it.
---

# Write convention entries

- An entry holds a convention the project settled, nothing more: the
  most general shape that holds across the project, stated as what must
  hold rather than how the code does it today. One case of that shape is
  not an entry of its own.
- An entry that would need rewriting when a library, a protocol or a
  number changes holds mechanism, not convention. A unit, a count, a
  field name, a library or a protocol in the sentence is the tell.
- An entry forbids something a contributor might otherwise reasonably
  do. One that forbids nothing is describing a habit.
- An entry stays while its convention does. A check that enforces it
  never replaces it: checks are loosened and lost, and only the entry
  says the check was right.
- A proposed entry is its exact final text, one demand per line, each
  line already held to the bar above. What misses the bar is not
  proposed.
