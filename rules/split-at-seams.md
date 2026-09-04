---
enforce: [before-acting, before-finishing]
summary: Split at real concern boundaries, and name a file so its contents are predictable.
autonomy: >
  A file may be split along a seam the finding names, into siblings named for
  what they hold, leaving what the package publishes unchanged. Where the seam
  is arguable, it goes to the operator with the candidates it would have chosen
  between.
---

# Split at seams

Split files at logical seams. A filename must predict its contents.

- Split where a real concern boundary exists — not at a line count.
- One file, one clear concern. Never let one file collect unrelated ones.
- ~150 lines is a fallback signal to split, not a target to fill. A cohesive file over the signal is fine — never split where there's no seam just to hit a number.
- Name it so the content is obvious without opening it.
- Don't withhold a split because there's only one caller today. It's cheap now and pays off later.
- Splitting is easy to undo. Bias toward more files.

This is settled where a seam exists: don't re-ask whether splitting is
worthwhile, just split. Whether the seam is real is a different question, and
still worth asking — a file over the signal with nothing to cut along is a
file that stays whole.

Related:
- [folder-shape](folder-shape.md) — what the tree looks like once the pieces exist.
- [design-for-growth](design-for-growth.md) — reuse arrives; split now while it's cheap.
- [propose-dont-decide](propose-dont-decide.md) — file naming and placement are the operator's call.
