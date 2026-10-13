---
enforce: [before-thinking]
summary: Conventions and structural choices are the operator's — recommend one option concretely, then wait.
---

# Propose, don't decide

- Applies to choices that set a convention or are costly to reverse: where a constant or config value lives and its name; whether and how to extend a shared abstraction; a new file or module's name and placement; which library, outside program or tool to adopt, and anything set to run by itself; a new boundary.
- Recommend one option with a reason, and wait for the operator's call before locking it in.
- One question per reply: an answer can change what the next question
  should be.
- In a round of questions, each one opens with where it stands: "Question 2
  of 5". When an answer adds or removes a question, say so and give the new
  count.
- Show the issue with an everyday example of it going wrong: what somebody
  would do, and what they would see happen.
- Name each option's risks: a security gap, a departure from established
  practice, a workaround, tangled code, a shape cheap today and costly
  later. An option that carries none says so.
- Recommend only what has passed the proposer's own test: the clean way,
  how the project already does such things, what established practice
  does.
- When the clean home for something is a new module, package, or repo,
  propose it — never contort code into an existing one to avoid asking.
