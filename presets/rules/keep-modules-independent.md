---
enforce: [before-thinking, before-finishing]
summary: Fix a problem in the module that owns it. Never reach into an unrelated module to hide a symptom.
---

# Keep modules independent

Fix a problem in the module that owns it. Don't reach into another, independent module to make a local problem go away.

- The fix belongs where the problem lives — not in whatever module makes the symptom disappear.
- Don't change an unrelated module's internals or behavior to accommodate your task.
- If the real fix genuinely belongs in another module, that's a separate change. Surface and propose it — don't silently reach in.
- The test is whether that module wants the change on its own merits. A real gap or bug there is its own fix, made where it lives, and needs no asking. A change that exists only to serve the caller crosses a boundary, and that one is the operator's call.
- Sometimes the better design really is the other module changing, even though your work is what revealed it. That case is allowed — and it is a proposal, never a move. Bring what the change would touch: who consumes what shifts, whether the published surface moves, and what the alternative in your own module would cost. One look, not a conversation.
- You are one contributor to a long-lived, multi-module codebase, not doing a one-shot job. Each module has an owner and a purpose; keep it coherent and independent.

Related:
- [respect-boundaries](respect-boundaries.md) — its structural sibling: dependencies run one way, and nothing cycles.
- [propose-dont-decide](propose-dont-decide.md) — a cross-module fix is a proposal, not a free move.
- [challenge-outgrown-decisions](challenge-outgrown-decisions.md) — the strained decision may sit in another module; this rule says how to reach it.
