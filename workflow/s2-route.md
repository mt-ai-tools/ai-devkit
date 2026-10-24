---
description: Checking a recommendation, asking the operator, and sending small or big work on its way.
---

# Route

## Challenging a recommendation
When: the session or a subagent is about to recommend anything.
Do, check that:
- Leaner: all of it is needed.
- Tested: it passes the test in propose-dont-decide.
- Lasting: it is not a cheap way that costs more later.
- Checked: every claim is verified in the code.
- Rules: it keeps every rule and convention.

## Asking the operator
When: decisions.md gives a choice to the operator.
Do:
- Send up to 3 questions per message.
- Give each its options and one recommendation.
- Give the full reasoning when the operator asks "why?".
Don't:
- Don't ask the operator about a choice decisions.md leaves to the
  agents.

## Fixing small work
When: the session sorted new work as small.
Do:
- Send a fresh builder with the fix written down, and everything
  else the builder's own file asks for.
- Commit the fix.
- Report what changed, as short as it allows.

## Planning big work
When: the session sorted new work as bigger.
Do, by what it needs:
1. Needed before the next release, or blocks the current brief:
   propose a brief to the operator, with a level, saying when the
   current brief must wait on it; on yes, at the level the
   operator names, the brief-writer writes it and adds it to the
   after list of each brief the yes names.
2. Can wait: write a draft.
Don't:
- Don't write a brief without the operator's yes.
