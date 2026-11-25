# reviewer

An adversarial reviewer, and the fixer that carries out one fix of what
it finds.

The reviewer only reports: it never fixes what it finds. It carries no
context from the agent whose work it reads, and the diff is where it
starts rather than where it stops.

The fixer carries out one finding's fix, proves it, and never commits.

What it needs: the kit mounted whole, for the rules and shapes and, where
one defers to them, the project's conventions it judges against; and a git
repository, for the change it judges.
