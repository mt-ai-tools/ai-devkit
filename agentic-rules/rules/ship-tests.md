---
enforce: [before-finishing]
summary: Ship the tests with the change, not after it.
autonomy: >
  A test may be added for behavior the finding names, asserting what the code
  promises rather than how it does it. Where the behavior is written down
  nowhere, it goes to the operator with what would have to be assumed.
---

# Ship tests

Ship the tests with the change, not after it.

- A bug fix in executable code ships a test that fails before and passes after.
- A new executable module ships tests for its observable behavior.
- Prose — specs, prompts, docs — needs no tests: nothing executes there.
- Tests assert behavior, not implementation detail.
- A test pins a value the outside world fixes — an environment key, a status
  code, a header, a filename another tool expects — by spelling it literally.
  A test that reads the constant it asserts, asserts nothing: change the
  constant to anything and the suite stays green while the contract breaks.
  The duplicate spelling is not a second copy of a fact; it is the assertion.
- Values that are yours to change — screen copy, log text — are the opposite
  case: tests read them from their one home, and the test binds the wiring,
  not the words.

How much is enough is settled here, so neither the writer nor a reviewer
argues it per file:

- Every public function gets two tests: one good input showing what it
  promises, one bad input showing how it refuses. That is the floor, and for
  most code it is also the ceiling.
- A bug fix's test carries a one-line comment beginning `// regression:` that
  names the bug it guards. No other test carries a category label.
- More is owed only where a failure would be invisible in use — an
  authentication path, a data write — because there the tests are the only
  witness.
- A surface still changing shape gets the floor and nothing more. A test
  written against a shape that moves next week is written twice.

Related:
- [centralize-constants](centralize-constants.md) — defers to this for literals inside tests.
- [single-source-of-truth](single-source-of-truth.md) — defers to this for the same; a pinned contract is not a drifting copy.
