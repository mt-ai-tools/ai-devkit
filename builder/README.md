# builder

A worker that builds one step of a brief, or a small fix, with the
checks and the hook that keep it honest and short.

Nothing here plans, judges, or commits: the session that starts a
builder keeps the brief, reads the builder's changes, and commits. A
builder carries no context from that session and keeps nothing between
steps. Where its step needs a decision it was not handed, it stops and
reports rather than decides.

Needs what the workflow says a builder is handed.
