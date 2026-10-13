---
enforce: [before-thinking, before-finishing]
summary: A consumer composes what the shared modules provide; anything generic it had to invent is a gap to report, not to build.
---

# Compose, don't invent

A consumer holds what makes it itself, and nothing else.

- What it contains is its own behaviour: its flows, its rules, the parts
  nothing else could supply. Everything generic underneath comes from the
  shared modules.
- Reaching an outside service directly goes around the shared modules rather
  than extending them.
- Where something generic must be invented, that is the finding: name the
  module that should own it, or say none does, and stop.
- The same goes for a workaround. Working around a module's shape describes a
  gap in that module.
