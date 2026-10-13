---
enforce: [before-thinking, before-finishing]
summary: Fix a problem in the module that owns it. Never reach into an unrelated module to hide a symptom.
---

# Keep modules independent

- A change in another module is tested by whether that module wants it on its own merits. A real gap or bug there is its own fix, made where it lives, and needs no asking. A change that exists only to serve the caller crosses a boundary, and that one is the operator's call.
- When the better design is the other module changing, even though your work revealed it, propose it — never make the move. Bring what the change would touch: who consumes what shifts, whether the published surface moves, and what the alternative in your own module would cost.
