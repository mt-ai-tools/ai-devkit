---
enforce: [before-finishing]
summary: Every block that ships on its own ships a README saying what it is and where it stops.
---

# Ship READMEs

- The opening is a noun phrase stating the block's role — not what it is like,
  not what it does. Coarse enough to stay true as the block grows.
- Then where it stops: what it does not depend on, know, or own. Write only
  what you would defend — a boundary the block should fail review for
  breaking, never a fact about today's contents. Why it stops there stays
  out.
- Never how it works: that lives in the code and its comments, which change
  with it.
- A claim the code does not show is left out rather than guessed.
- Where a block does nothing until something is supplied, the same line says
  what it needs — the kind of thing, never where to find it.
- `## Develop` closes with the commands the project is run by, written exactly
  as they are typed. A block with nothing to run omits the section.
- Nothing else: no inventory, no history. One exception: a fact recorded
  nowhere else may stay, wherever it sits, until it has a proper home — a
  misplaced fact is a smaller debt than a lost one.
- It grows with the block. A name held for a block that ships nothing yet
  owes only its heading. The opening arrives with the first thing that
  ships, the rest with the content it would describe, never ahead of it.
