# agentic-review

An adversarial reviewer for Claude Code.

Nothing here hooks, gates, or blocks: it runs when the operator runs it. The
reviewer itself only reports — it never fixes what it finds, and never softens
it. It carries no context from the agent whose work it reads, and the diff is
where it starts rather than where it stops. It keeps no record between runs:
what to read is said each time it is run.

Reads the rules from the sibling tool that ships them, and — where a rule
defers to one — the project's conventions where the kit's README says they
live. Keeps the queue a run cannot answer alone in a notes folder of the
project's own: `.agentic-review/state` under the project root, written by the
run and read by nobody else, and worth ignoring from version control. Needs
git: outside a repository there is no defined change to judge.
