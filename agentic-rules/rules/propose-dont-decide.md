---
enforce: [before-thinking]
summary: Conventions and structural choices are the operator's — recommend one option concretely, then wait.
---

# Propose, don't decide

Conventions and structural choices are the operator's call. Propose a concrete recommendation; let the operator decide.

- Applies to choices that set a convention or are costly to reverse: where a constant or config value lives and its name; whether and how to extend a shared abstraction; a new file or module's name and placement; which library to adopt; a new boundary.
- Propose concretely — recommend one option with a reason. Don't hand over a blank question; hand over a decision.
- Wait for the operator's call before locking it in.
- Not "pause on every line" — only choices that shape the codebase or are annoying to undo.
- The gate is also an invitation: when the clean home for something is a new module, package, or repo, propose it — never contort code into an existing one to avoid asking. Asking is cheap; a misplaced home hardens.
