---
enforce: [before-thinking, before-acting, before-finishing]
summary: The outside is hostile. Name what an attacker gains before shaping a change, refuse what cannot be decided, and keep secrets where only the deployment reads them.
autonomy: >
  A refusal that names which check failed may be reworded to the generic
  refusal the code already answers elsewhere. A secret found anywhere is
  reported and never removed by the run: deleting the copy would hide that
  it was seen, and rotating it is the operator's. A path that fails open is
  the operator's too — closing it changes what callers get.
---

# Expect an attacker

Whatever reaches the code from outside was sent by someone who wants
what it guards.

- Before shaping a change that touches who may do what, money, personal
  data, or a boundary with the outside, write three lines: what an
  attacker gains if this is wrong, and the check that stops them. They
  open the proposal, and are read before the code is.
- Fail closed. What cannot be decided is refused: no reasons means no
  access, unreadable configuration means no boot, an error nobody
  classified is not retried, and no error path grants what the happy
  path checks.
- A secret lives only where the deployment reads it. Never in a commit,
  a log line, a failure message, a fixture, a URL, or a conversation. A
  secret that has been seen is rotated, never deleted from history —
  history is a copy, and the copy that matters is the one already taken.
- A refusal tells the caller to stop, never which check failed or
  whether the thing asked about exists. What went wrong is for the log.

Related:
- [ship-tests](ship-tests.md) — a door is tested with the stranger, not only the invited.
- [library-first](library-first.md) — a dependency is one more party inside the boundary.
- [centralize-constants](centralize-constants.md) — configuration is read through one loader, which is where a secret's one home is.
- [odd-means-unfinished](odd-means-unfinished.md) — a check that needs an exception is a check not yet placed.
