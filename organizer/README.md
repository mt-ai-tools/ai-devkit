# organizer

A work organizer over a folder of briefs: what is ready to start, what waits
and on what, what one brief waits on, what a session has taken, which ready
briefs would work where a taken one already does, which taken briefs work
where a path lies, and the drafts not yet written out — and the one writer of
a new brief, in the one shape a brief has, once the operator has said yes to
it.

The order of the work is derived, never kept: each brief's header says what
must land before it and where it works, and nothing else holds a copy of
either. How much a brief matters is the level folder it lies in, and nothing
else records it: the order shown is the operator's, read off the levels, and
the organizer ranks nothing itself. Ready, waiting and taken briefs each show
their level, and come in level order, then by name. It is asked in plain
words, through a skill whose hook shows the user the list exactly as printed.
A brief its header check cannot vouch for is shown as a problem and never
offered as work; a name it cannot find is an error, never read as finished.
Only a ready brief can be taken: one still waiting is refused, naming what it
waits on.

A draft is an item decided on but not yet written out as a brief, marked so
in its header and held to a summary. It is never offered or taken. The list
counts the drafts in each level and names those in the most urgent one; the
organizer lists every draft in full, or one level's, on request. A new draft
is written through the organizer, never by hand, into the level its caller
picks: it is handed the summary on the first line, then the draft's text,
opening with its title line. It writes only where no brief or draft of that
name stands in any level, and never makes a level folder.

It changes only its own marks; when a brief is finished, that brief and the
after lists naming it; and when a wait on another brief is written into a
brief, that brief's after list; and when a draft is written, that one new
file. Its writer adds only the one new brief, and the after lists the
operator's yes named. Neither runs version control: finishing, a written wait
and a written draft print every path they changed, and committing them is
left to whoever called it.

Needs a folder of briefs holding four level folders, made by hand, and
nothing else: `p1-critical`, `p2-required`, `p3-conditional` and
`p4-optional`. The levels are the kit's own, the same in every project; what
each means is held with their names in the kit, and shown wherever a level is
refused.

Each brief in them opens with a header of four fields — a one-line summary,
the briefs it waits on, the existing paths it works in, and the paths it
brings into being — and each draft with its summary and its draft mark. Needs
a working folder of its own for the marks, which holds nothing worth sharing
beyond one machine. Needs nothing but `bash`, `awk` and `jq`.
