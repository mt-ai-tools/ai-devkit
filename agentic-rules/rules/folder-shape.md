---
enforce: [before-acting, before-finishing]
summary: A folder holds files or subfolders, never a mix — and once one sibling is worth grouping, group them all.
---

# Folder shape

A folder holds files or subfolders, never a mix.

- Once any sibling is worth grouping, group them all — including the entry point, and a group of one.
- A lone file beside folders reads as an oversight. Consistency you can see beats a convention a reader has to already know.
- Three exceptions: a folder's own README, which documents the folder it sits in; files a tool requires at a fixed location, like `.gitignore` at a repo root; and pure re-export files (`index.ts`, `api.ts`, and the like) that only re-export what lives in the sibling folders — the moment one gains logic of its own, the exception ends.
- A folder and a file inside it never carry the same name. The folder
  said it already; the file saying it again says nothing and leaves the
  concern's second piece nowhere obvious to go.

Related:
- [split-at-seams](split-at-seams.md) — when a file becomes two; this says where the two then sit.
- [propose-dont-decide](propose-dont-decide.md) — sibling naming and placement are the operator's call.
