# builder

A worker that carries out one step of a written brief.

Nothing here plans, judges, or commits: the session that launches it keeps
the brief, the order of the steps, the reading of each diff against the
brief, and the commit. It carries no context from that session, and keeps
nothing between steps — what it knows of the work is what the brief and the
rules say. Where the step needs a decision the brief does not make, it stops
and reports rather than decides.

Needs a brief written down, and the locations of the rules and the
project's conventions handed to it by the session, which reads them from
what the injector printed at the start of the turn.
