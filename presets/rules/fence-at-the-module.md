---
enforce: [before-thinking, before-finishing]
summary: An outside library stops at the module that binds it; no module is named after one.
---

# Fence at the module

A module that binds an outside library is where that library ends.

- Its names, types and error shapes stay inside. Everything else talks to the
  module's own contract.
- The module is the fence, and it is the only one. Nothing inside needs a
  second wrapper around the library.
- Two modules may each bind the same library for different concerns. That is
  not a fork: each owns a different contract.
- A module is named for what it does, never for the library inside it.
