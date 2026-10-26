---
description: Building a brief one step at a time, each step with a fresh builder.
---

# Build

## Taking a brief
When: the operator says go on a brief.
Do:
- The session takes the brief with the organizer's take command, so
  no other session starts it.

## Building a step
When: the brief has a step not yet built.
Do, in this order:
1. The session starts a fresh builder with everything the builder's
   own file asks for.
2. The builder builds the step and proves it as the step says.
3. The session reads the builder's changes against the step.
4. The session commits them and marks the step built in the brief,
   as the brief-writer's file says.
5. The session shows the operator each Told or Advisor decision made
   in the step, laid out as decisions.md says.
Don't:
- A builder doesn't commit.
- The session doesn't send a builder more work after it reports:
  answers, fixes and the next step each go to a fresh builder.

## A builder grows long
When: the kit's size hook tells a builder it has grown long.
Do:
- The builder stops and reports as its own file says.
- A fresh builder carries on with what is left.

## A red no step explains
When: a builder reports a red its step does not explain.
Do:
- Once the step is committed and pushed, the session takes a clean
  copy of the pushed work through the copy command the kit's settings
  name, runs that suite in it, and gives the copy back.
- Green there: someone else's unfinished work caused it; the session
  says so to the operator.
- Red there: the session runs it once more in the copy as it stood
  before the step. Green before: the step broke it, and a fresh
  builder fixes it. Red before too: it is not the step's; the session
  says so to the operator.

## Building steps side by side
When: two or more steps need nothing from each other and change
  different files.
Do:
- The session starts one builder for each, and reads and commits
  each on its own.

## A builder stops
When: a builder meets a choice or a gap the step does not answer.
Do:
- The session sorts it as s1-intake.md says.
- The session writes the answer into the brief, as the brief-writer's
  file says a decision is written.
- A fresh builder carries on.

## Pausing to compact
When: a step is committed and marked, or a brief's answers are
  written into it and committed, and the kit's session size check
  says the session is worth compacting.
Do:
- The session stops and tells the operator: "Good point to
  compact: everything is in the brief. Type /compact, then go."
- The session carries on with the next step at the operator's go.
