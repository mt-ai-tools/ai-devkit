# organizer

A work organizer over a folder of briefs: what is ready to start, what waits
and on what, what a session has taken, and which briefs would work in the
same place.

The order of the work is derived, never kept: each brief's header says what
must land before it and where it works, and nothing else holds a copy of
either. It ranks nothing — which ready brief comes first is the operator's
pick. A brief its header check cannot vouch for is shown as a problem and
never offered as work; a name it cannot find is an error, never read as
finished.

It changes only its own marks, and, when a brief is finished, that brief and
the after lists naming it. It never runs version control: finishing prints
every path it changed, and committing them is left to whoever called it.

Needs a folder of briefs, each opening with a header of four fields — a
one-line summary, the briefs it waits on, the existing paths it works in,
and the paths it brings into being — and a working folder of its own for the
marks, which holds nothing worth sharing beyond one machine. Needs nothing
but `bash` and `awk`.
