# builder

A worker that builds one step of a brief, or a small fix, with the
checks and the hook that keep it honest and short.

Nothing here plans, judges, or commits: the session that starts a
builder keeps the brief, reads the builder's changes, and commits. A
builder carries no context from that session and keeps nothing between
steps. Where its step needs a decision it was not handed, it stops and
reports rather than decides.

- The break check proves a test by breaking what it guards, and always
  puts the file back.
- The size check tells a session when it is worth compacting. It decides
  nothing.
- The size hook tells a builder that has grown long to stop.

Needs what the workflow says a builder is handed.
