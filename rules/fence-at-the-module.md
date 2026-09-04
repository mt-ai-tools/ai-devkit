---
enforce: [before-thinking, before-finishing]
summary: An outside library stops at the module that binds it, and no module is named after one.
---

# Fence at the module

A module that binds an outside library is where that library ends.

- Its names, types and error shapes stay inside. Everything else talks to the
  module's own contract, and could not tell from reading it which library is
  behind it.
- The module is the fence, and it is the only one. Nothing inside needs a
  second wrapper around the library — that is a cost with no boundary to show
  for it.
- Two modules may each bind the same library for different concerns. That is
  not a fork: each owns a different contract, and neither knows the other did
  the same.
- A module is never named for the library inside it. Two modules doing the
  same kind of work are told apart by what they do, never by whose code they
  hold.

Related:
- [respect-boundaries](respect-boundaries.md) — the same containment among your own layers.
- [library-first](library-first.md) — use a library freely; this says where it stops.
- [blocks-not-bundles](blocks-not-bundles.md) — a block declares what it needs as a contract, not a place.
- [compose-dont-invent](compose-dont-invent.md) — what a product reaches for directly is a module that does not exist yet.
