---
enforce: [before-acting, before-finishing]
summary: Prose describes in roles — it never restates an identifier, path, or dependency that code already holds.
autonomy: >
  An identifier may be reworded out of prose. Where the sentence has nothing
  left once the name is gone, it goes to the operator with that sentence and
  what it was carrying.
---

# Describe, don't name

Prose describes what a thing is for. It never restates what code already holds.

- Code is the source of every identifier, path, export, and dependency in it.
  A doc that repeats one is a second copy, and it rots silently — nothing
  checks prose.
- Write in roles: what a piece does, what it must not do, what it needs.
  Not what it is called, or where it sits.
- This binds every doc, whatever its kind — the exemptions below are the whole
  list.
- No usage examples. Code that needs prose to explain how to use it is code to
  fix, not to document, and an example nothing compiles is wrong from the
  first rename.

Exempt:

- Steps a human types verbatim may name external tools and their fixed files.
  Those names are not yours to change, so they cannot go stale from within.
- Languages, formats, and platform features may be named. They are the medium
  the prose is written about, not identifiers your code holds.
- Prose may point at sibling prose. A broken link is findable; a stale
  identifier is not.
- A migration note names freely. It records what one past release broke,
  frozen at its date — its identifiers are history, and history cannot rot.
- A why-comment may name the specific library, tool, or version that caused
  what it explains. When the name is the why — a dependency's bug, a vendor's
  quirk — writing around it would hide the reason.
- A placeholder form may show a shape a convention prescribes, when the shape
  is the point. Use it sparingly: a form shown in one entry and withheld in
  the next reads as a distinction that isn't there.

Related:
- [single-source-of-truth](single-source-of-truth.md) — its premise; the identifier's home is the code.
- [blocks-not-bundles](blocks-not-bundles.md) — a block that names its neighbours in prose knows them just as surely.
- [human-readable](human-readable.md) — why no usage example is needed: the code reads without one.
