---
enforce: [before-thinking, before-finishing]
summary: Ship the smallest unit that stands alone, and never let it know who uses it.
---

# Blocks, not bundles

Build from small independent blocks. Each one ships, versions, and is replaced by
itself.

- Split at the seam where a piece could be useful on its own — not where it is convenient today.
- Where there is no seam, there is no block: a split follows a boundary
  rather than making one.
- A shared subject is not a shared shape. A piece built around one consumer's
  data model is that consumer's, however general its topic sounds.
- Split early rather than late. An early split is paid once and in the open;
  a late one is paid in copies.
- "They are always used together" is a reason to compose them, not to ship them as one.
- A block may know the layers beneath it and nothing of those above — not
  their names, not where they sit, not the system it is part of.
- A block may declare what it *needs* — as a contract it accepts, not a place it expects to find one.
- Where a dependency must be named, name it once, in one place, and let the location be configurable.
