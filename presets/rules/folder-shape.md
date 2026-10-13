---
enforce: [before-acting, before-finishing]
summary: A folder holds files or subfolders, never a mix — and once one sibling is worth grouping, group them all.
---

# Folder shape

- Grouping takes in the entry point too, and makes a group of one where needed.
- A lone file beside folders reads as an oversight. Consistency you can see beats a convention a reader has to already know.
- Exceptions: a folder's own README; files a tool requires at a fixed location, and the template such a file is copied from; at a block's root, the examples it ships for a project to copy into itself; and pure re-export files that only re-export what lives in the sibling folders — the moment one gains logic of its own, the exception ends.
- A folder and a file inside it never carry the same name.
