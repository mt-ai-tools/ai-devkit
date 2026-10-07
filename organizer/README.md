# organizer

A work organizer over a folder of briefs: what is ready to start, what waits
and on what, what one brief waits on, what a session has taken, which ready briefs would work where
a taken one already does, and which taken briefs work where a path lies — and the one writer of a new brief, in the
one shape a brief has, once the operator has said yes to it.

The order of the work is derived, never kept: each brief's header says what
must land before it and where it works, and nothing else holds a copy of
either. It ranks nothing — which ready brief comes first is the operator's
pick. It is asked in plain words, through a skill whose hook shows the user
the list exactly as printed. A brief its header check cannot vouch for is shown as a
problem and never offered as work; a name it cannot find is an error, never
read as finished. Only a ready brief can be taken: one still waiting is
refused, naming what it waits on.

It changes only its own marks; when a brief is finished, that brief and the
after lists naming it; and when a wait on another brief is written into a
brief, that brief's after list. Its writer adds only the one new brief, and
the after lists the operator's yes named. Neither runs version control:
finishing and a written wait print every path they changed, and committing
them is left to whoever called it.

Needs a folder of briefs, each opening with a header of four fields — a
one-line summary, the briefs it waits on, the existing paths it works in,
and the paths it brings into being — and a working folder of its own for the
marks, which holds nothing worth sharing beyond one machine. Needs nothing
but `bash`, `awk` and `jq`.
