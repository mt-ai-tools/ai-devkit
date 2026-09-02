---
enforce: [before-finishing]
summary: A breaking change ships its migration note in the same commit.
autonomy: >
  A note may be written for a break the finding establishes. Whether something
  is a break is not this fix's to decide.
---

# Ship migration notes

A change that breaks a published surface ships a migration note with it.

- Breaking means a consumer of the previous version must change something to keep working.
- The note answers one question: what broke, and how does a consumer adapt. Nothing else.
- It lives in the module that broke, in that module's `MIGRATION.md`, newest entry first — not in any central collection, which would drift.
- It ships in the same commit as the break. No note, no breaking change.
- It names the release it shipped in, because the reader is deciding whether it
  applies to the jump they are making. Never a date: the reader is not upgrading
  from a Tuesday, and the repository already knows when the note landed.
- Before the first release, a break ships no note: nobody can be holding the
  version it broke, and there is no release to name. The first release is the
  baseline every later note is written against.
- Internal changes need no note: if no published surface moved, there is nothing to migrate.

Related:
- [ship-tests](ship-tests.md) — the same discipline for executable behavior.
- [single-source-of-truth](single-source-of-truth.md) — the note lives where the break lives; collections reference it.
