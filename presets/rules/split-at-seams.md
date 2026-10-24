---
enforce: [before-acting, before-finishing]
summary: Split at real concern boundaries, and name a file so its contents are predictable.
---

# Split at seams

- One file, one clear concern.
- Not at a line count: ~150 lines is a fallback signal to look for a seam, not a target to fill.
- Don't withhold a split because there's only one caller today.
- Splitting is easy to undo. Bias toward more files.

Where a seam exists, split without asking whether it is worthwhile. Whether
the seam is real is still worth asking — a file over the signal with nothing
to cut along stays whole.
