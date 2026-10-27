---
description: Who decides each kind of choice and fix, and what the operator sees.
---

# Decisions

| Choice                                                                      | Level               |
|-----------------------------------------------------------------------------|---------------------|
| A name inside the code, the shape of a test, how a step is built            | Silent              |
| An approach, a data shape, where code sits inside a module                  | Told                |
| Now or later, the order of steps                                            | Told (default: now) |
| A Told choice the agent is unsure of                                        | Advisor             |
| What a person using the app sees: wording, defaults, promises               | Operator            |
| Accepting a security risk or a known limit                                  | Operator            |
| A module added, removed, split, merged or named; which module may use which | Operator            |
| A library, a vendor, anything paid                                          | Operator            |
| A rule or convention made or changed                                        | Operator            |
| A new brief, and its level                                                  | Operator            |
| Undoing a decision the operator made                                        | Operator            |

## Fixes

| Fix                                                                               | Level    |
|-----------------------------------------------------------------------------------|----------|
| Flattening nesting, or renaming a name used only in its file, behaviour unchanged | Told     |
| Renaming anything used beyond its file                                            | Told     |
| Rewording a refusal to the generic one the code already gives                     | Told     |
| Removing or rotating a secret                                                     | Operator |
| Closing a path that fails open                                                    | Told     |
| Writing a missing why-comment whose reason the code, its tests or its commit show | Told     |
| A why-comment whose reason would have to be guessed                               | Operator |
| Rewriting a sentence that names a block's user, to say what the block is          | Told     |
| A block that truly depends on its user                                            | Operator |
| Rewording a name from the code out of prose                                       | Told     |
| A sentence with nothing left once the name is gone                                | Told     |
| Writing or reshaping a README from what the code shows                            | Told     |
| Adding a test for behaviour a finding names                                       | Told     |
| A test for behaviour written down nowhere                                         | Told     |
| Lifting a named concern out of a file, or splitting a file along a named seam     | Told     |
| A concern or seam that is arguable                                                | Advisor  |
| Moving a literal to a named constant, and naming it                               | Told     |
| A constant that needs a new home inside an existing module                        | Told     |
| Writing a migration note for a break a finding establishes                        | Told     |
| Whether a change is a break                                                       | Advisor  |
| Deleting a copy where the source is named                                         | Told     |
| A copy where either place could be the source                                     | Advisor  |

## Levels

| Level    | Who decides                                                                                                            | The operator sees      |
|----------|------------------------------------------------------------------------------------------------------------------------|------------------------|
| Silent   | The working agent                                                                                                      | Nothing                |
| Told     | The working agent, after challenging it (s2-route.md)                                                                  | The decision, laid out |
| Advisor  | One fresh advisor per choice, started by the session with the choice, the brief where there is one, and where the rules live; it is sent the proposal only after it has answered | The decision, laid out |
| Operator | The operator, asked by the session (s2-route.md); no agent, even when the answer looks obvious                         | The question           |

A decision is laid out as: the question, the options, the one chosen,
why, and what could go wrong.

A subagent never starts an advisor or asks the operator; it lists
the choice in its report.
