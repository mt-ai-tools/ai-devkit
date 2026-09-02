---
enforce: [before-thinking, before-finishing]
summary: Ship the smallest unit that stands alone, and never let it know who uses it.
autonomy: >
  A sentence naming a consumer may be rewritten to say what the block is
  instead — prose knowing its neighbours costs nothing to unsay. Where the
  block reaches them for real, in a dependency, an import, or an interface
  shaped around one, the fix changes what the block is, and that is the
  operator's.
---

# Blocks, not bundles

Build from small independent blocks. Each one ships, versions, and is replaced by
itself.

- Split at the seam where a piece could be useful on its own — not where it is convenient today.
- "They are always used together" is a reason to compose them, not to ship them as one.
- A block never knows its consumers. No naming them, no describing where they sit, no explaining the system it happens to be part of.
- A block may declare what it *needs* — as a contract it accepts, not a place it expects to find one. "A directory of rule files" is a contract; "the folder next to me" is a layout assumption.
- Where a dependency must be named, name it once, in one place, and let the location be configurable.
- A block that cannot be described without describing its neighbours is not a block yet.

Related:
- [keep-modules-independent](keep-modules-independent.md) — the same independence inside one codebase.
- [compose-dont-merge](compose-dont-merge.md) — combine blocks with a thin orchestrator; never fuse them.
- [single-source-of-truth](single-source-of-truth.md) — a fact repeated in two blocks drifts twice as fast.
