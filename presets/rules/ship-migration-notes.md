---
enforce: [before-finishing]
summary: A breaking change ships its migration note in the same commit.
autonomy: >
  A note may be written for a break the finding establishes. Whether something
  is a break is not this fix's to decide.
---

# Ship migration notes

- Breaking means a consumer of the previous version must change something to keep working.
- The note answers one question: what broke, and how does a consumer adapt. Nothing else.
- It lives in the module that broke, in that module's `MIGRATION.md`, newest entry first — never in a central collection.
- It names the release it shipped in, so the reader can tell whether it
  applies to the jump they are making. Never a date.
- Before the first release, a break ships no note: nobody holds the version
  it broke. The first release is the baseline every later note is written
  against.

No note, no breaking change.
