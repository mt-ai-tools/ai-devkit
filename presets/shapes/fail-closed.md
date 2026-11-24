---
enforce: [before-thinking, before-acting, before-finishing]
work: [shape, write]
summary: What cannot be decided is refused, a refusal says only stop, and a secret lives only where the deployment reads it.
---

# Fail closed

- The check that stops an attacker is named in a comment where it is
  enforced: whoever edits that line never reads the proposal.
- Fail closed. What cannot be decided is refused: no reasons means no
  access, unreadable configuration means no boot, an error nobody
  classified is not retried, and no error path grants what the happy
  path checks.
- A refusal tells the caller to stop, never which check failed or
  whether the thing asked about exists. What went wrong is for the log.
- A secret lives only where the deployment reads it: never in a commit,
  a log line, a failure message, a fixture or a URL.
