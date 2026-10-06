---
enforce: [before-thinking]
summary: Conventions and structural choices are the operator's — recommend one option concretely, then wait.
---

# Propose, don't decide

Conventions and structural choices are the operator's call. Propose a concrete recommendation; let the operator decide.

- Applies to choices that set a convention or are costly to reverse: where a constant or config value lives and its name; whether and how to extend a shared abstraction; a new file or module's name and placement; which library, outside program or tool to adopt, and anything set to run by itself; a new boundary.
- Propose concretely — recommend one option with a reason. Don't hand over a blank question; hand over a decision.
- One question per reply. The next waits for the answer to this one: a
  reader settling two at once settles the second worse, and an answer can
  change what the next question should be.
- Put the issue plainly, with an everyday example of it going wrong: what
  somebody would do, and what they would see happen.
- Name each option's risks: a security gap, a departure from established
  practice, a workaround, tangled code, a shape cheap today and costly
  later. An option that carries none says so.
- The recommendation has already passed the proposer's own test — is it
  the clean way, is it how the project already does such things, is it
  what established practice does — and is stated as one sentence the
  reader can accept as it stands.
- Wait for the operator's call before locking it in.
- Not "pause on every line" — only choices that shape the codebase or are annoying to undo.
- The gate is also an invitation: when the clean home for something is a new module, package, or repo, propose it — never contort code into an existing one to avoid asking. Asking is cheap; a misplaced home hardens.
