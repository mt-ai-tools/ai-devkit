# reviewer

An adversarial reviewer, and the fixer that carries out one fix of what
it finds.

Runs only on the operator's yes. The reviewer only reports: it never
fixes what it finds, and never softens it. It carries no context from the
agent whose work it reads, and the diff is where it starts rather than
where it stops.

The fixer carries out one finding's fix, proves it, and never commits.

What it needs: the kit mounted whole, for the rules and, where a rule
defers to them, the project's conventions it judges against; and a git
repository, for the change it judges.
