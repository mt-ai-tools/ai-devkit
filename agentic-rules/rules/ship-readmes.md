---
enforce: [before-finishing]
summary: Every block that ships on its own ships a README saying what it is and where it stops.
autonomy: >
  A README may be written or reshaped in full, since every line it may carry is
  read off the code. A claim the code does not show is left out rather than
  guessed — an absent paragraph is honest, and nothing here needs asking. The
  last-copy exception binds here too: a fact's only copy is left where it
  stands — not deleted, and not queued.
---

# Ship READMEs

Every block that ships on its own ships a README with it.

- The opening is a noun phrase stating the block's role — not what it is like,
  not what it does. Coarse enough to stay true as the block grows.
- Then where it stops: what it does not depend on, know, or own. Write only
  what you would defend — a boundary the block should fail review for
  breaking, never a fact about today's contents. The code already shows what
  is there; this line is the only place that says what must never be. Why it
  stops there stays out: reasons belong where they were decided, dated and
  reviewed.
- Where a block does nothing until something is supplied, the same line says
  what it needs — the kind of thing, never where to find it. A reader who has
  just mounted it learns from the block that there is a declaration to make,
  rather than from whatever happens to consume it.
- `## Develop` closes with the commands the project is run by, written exactly
  as they are typed. A block with nothing to run omits the section.
- Nothing else. The source tree is the inventory and the log is the history;
  a README that repeats either is a second copy of both. One exception: a
  fact recorded nowhere else may stay, wherever it sits, until it has a
  proper home. A misplaced fact is a smaller debt than a lost one, and
  rehoming it is work that waits for whoever next touches its subject.
- It grows with the block. An embryonic one owes only its opening — the rest
  arrives with the content it would describe, never ahead of it.

Related:
- [describe-dont-name](describe-dont-name.md) — how every line of it is written.
- [ship-tests](ship-tests.md) — the same discipline for executable behavior.
- [blocks-not-bundles](blocks-not-bundles.md) — what the block stops at is what makes it one.
