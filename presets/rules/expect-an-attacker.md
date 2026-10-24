---
enforce: [before-thinking, before-acting, before-finishing]
summary: The outside is hostile: name what an attacker gains, refuse what cannot be decided, keep secrets where only the deployment reads them.
---

# Expect an attacker

Whatever reaches the code from outside was sent by someone who wants
what it guards.

- Before shaping a change that touches who may do what, money, personal
  data, or a boundary with the outside, open the proposal with what an
  attacker gains if this is wrong and the check that stops them.
- Weigh a gap by what an attacker gains against how rare it is, and
  let the operator choose: accepted in a comment beside the check, or
  a draft at a level.
- The check that stops them is named where it is enforced, not only in
  the proposal it opened: whoever edits that line never reads the
  proposal.
- Fail closed. What cannot be decided is refused: no reasons means no
  access, unreadable configuration means no boot, an error nobody
  classified is not retried, and no error path grants what the happy
  path checks.
- A secret lives only where the deployment reads it. Never in a commit,
  a log line, a failure message, a fixture, a URL, or a conversation. A
  secret that has been seen is rotated, never deleted from history.
- A refusal tells the caller to stop, never which check failed or
  whether the thing asked about exists. What went wrong is for the log.
