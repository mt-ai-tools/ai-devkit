# reviewer

An adversarial reviewer, and the fixer that carries out one fix of what
it finds.

Runs only on the operator's yes. The reviewer only reports: it never
fixes what it finds, and never softens it. It carries no context from the
agent whose work it reads, and the diff is where it starts rather than
where it stops.

The fixer carries out one finding's fix, proves it, and never commits.

The reviewer judges against the rules and, where a rule defers to one,
the project's conventions, so it runs only where the kit is mounted
whole. Needs git: outside a repository there is no defined change to
judge.
