---
enforce: [before-thinking, before-finishing]
work: [shape, write]
summary: Dependencies run one way, features meet at published interfaces, nothing forms a cycle.
---

# Respect boundaries

Keep layers and features separate. No reaching across.

- A module uses what sits below it, never what sits above. Which is below
  is declared once, where a tool refuses an import that points upward.
- No cross-layer imports.
- No cross-feature imports — features talk through shared, declared interfaces, not each other's internals.
- A dependency loop almost always means a piece sits in the wrong
  module. Sometimes a module needs an import, and the import would
  make a loop. Treat that case as a loop too.
- Before you propose a fix, look at the whole loop. Name each module
  or file in the loop. For each step, name the piece behind the
  dependency. Then find the case:
  - A piece sits too high. Move the piece down to the lowest module or
    file. All users of the piece must reach that module or file.
  - A module does two jobs, a low job and a high job. Split the module
    between the two jobs.
  - Several modules share a piece, and the piece has no home. Give the
    piece its own module.
  - A shape holds a low part and a high part. Put the low part in a
    small base shape in the low module. The high module adds the high
    part to the base shape.
  - The dependency points the wrong way. The low module declares its
    own shape for the dependency. The high module fills that shape.
- A copy, a type cast or an import made at run time never breaks a
  loop. Each one hides the wrong home and keeps the piece there.
- Time is a boundary too. What runs in production never depends on what
  exists only to build, test, or deploy it — those sit above it. A
  decision the running code must make is never taken from a module that
  stops existing once it is deployed.
