# builder

A worker that carries out one step of a written brief, the break check it
proves its tests with, and the size check the session running the brief
reads at its clean points.

Nothing here plans, judges, or commits: the session that launches it keeps
the brief, the order of the steps, the reading of each diff against the
brief, and the commit. It carries no context from that session, and keeps
nothing between steps — what it knows of the work is what the brief and the
rules say. Where the step needs a decision the brief does not make, it stops
and reports rather than decides.

The break check changes one place, runs the test command it is handed, and
calls the break proved only where the runner names the test as failed; it
always puts the file back. It knows the failed-test marks of the runners the
kit's projects use, and nothing of any project.

The size check reads a session's own transcript and says whether it has grown
worth compacting; it decides nothing, and is read only at a clean point of a
brief, never mid-work.

Needs a brief written down, and the locations of the rules and the
project's conventions handed to it by the session, which reads them from
what the injector printed at the start of the turn — with where the kit is
mounted from, and which packages use the one the step changes.
