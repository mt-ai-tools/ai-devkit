---
enforce: [before-thinking, before-finishing]
summary: A consumer composes what the shared modules provide; anything generic it had to invent is a gap to report, not to build.
---

# Compose, don't invent

A consumer holds what makes it itself, and nothing else.

- What it contains is its own behaviour: its flows, its rules, the parts
  nothing else could supply. Everything generic underneath comes from the
  shared modules, assembled rather than written.
- Reaching an outside service directly goes around the shared modules rather
  than extending them. Whatever was reached for is a job no module does yet.
- Where something generic must be invented, that is the finding: name the
  module that should own it, or say none does, and stop. Building it locally
  answers today and leaves the shared set a little less whole.
- The same goes for a workaround. Working around a module's shape describes a
  gap in that module, however politely.

Related:
- [fence-at-the-module](fence-at-the-module.md) — where an outside library stops.
- [keep-modules-independent](keep-modules-independent.md) — a fix belonging elsewhere is proposed, never reached for.
- [blocks-not-bundles](blocks-not-bundles.md) — shared modules are built to be composed from.
