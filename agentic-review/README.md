# agentic-review

An adversarial reviewer for Claude Code.

Nothing here hooks, gates, or blocks: it runs when the operator runs it. The
reviewer itself only reports — it never fixes what it finds, and never softens
it. It carries no context from the agent whose work it reads, and the diff is
where it starts rather than where it stops. It keeps no record between runs:
what to read is said each time it is run.

Judges against the kit's rules, and — where a rule defers to one — the
project's conventions; the command hands it both locations from what the
injector printed at the start of the turn, so it runs only where the kit is
mounted whole. Keeps the queue a run cannot answer alone in a notes folder of
the project's own, written by the run and read by nobody else, and worth
ignoring from version control. Needs git: outside a repository there is no
defined change to judge.
