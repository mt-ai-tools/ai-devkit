---
enforce: [before-acting, before-finishing]
summary: Prose describes in roles — it never restates an identifier, path, or dependency that code already holds.
---

# Describe, don't name

- Code is the source of every identifier, path, export, and dependency in it.
  A doc that repeats one is a second copy, and it rots silently — nothing
  checks prose.
- Write in roles: what a piece does, what it must not do, what it needs.
  Not what it is called, or where it sits.
- This binds every doc; the exemptions below are the whole list. An answer
  to the operator is not a doc: it is read once and cannot go stale, so
  there, naming the file, the path or the command is how the reader finds
  the thing.
- No usage examples. Code that needs one is code to fix, and an example
  nothing compiles goes stale at the first rename.

Exempt:

- Steps a human types verbatim may name external tools and their fixed files.
  Those names are not yours to change, so they cannot go stale from within.
- Languages, formats, and platform features may be named.
- Prose may point at sibling prose that lives at least as long as it
  does. A broken link is findable; a stale identifier is not. A lasting
  text never points at a temporary one that will be deleted while it
  still stands: it says the thing itself instead.
- A migration note names freely: its identifiers are history, and history
  cannot rot.
- A why-comment may name the specific library, tool, or version that caused
  what it explains.
- A placeholder form may show a shape a convention prescribes, when the shape
  is the point. Use it sparingly: a form shown in one entry and withheld in
  the next reads as a distinction that isn't there.
- A place the operator must make by hand may be named where they are told
  to make it.
