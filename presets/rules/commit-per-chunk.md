---
enforce: [before-thinking]
summary: Commit each coherent chunk as it lands, without asking; never let changes pile up.
---

# Commit per chunk

- A good boundary: one coherent thing is done and works.
- Don't mix several features into one commit.
- Don't let changes pile up past a boundary — one unbroken run is harder to review and revert than several commits.
- Write the message yourself: what changed and why.
- The commit isn't the risky step; losing the boundary is. Pushing is another step: it reaches other people.
