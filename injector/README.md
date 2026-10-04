# injector

A rule-injecting prompt hook for Claude Code: one summary line per rule,
every turn.

Injects, and nothing else — it enforces nothing, and blocks one thing only:
a turn the rules did not reach is refused, with the reason shown to the
operator, rather than run without them. It copies
no rule text anywhere: each line quotes the summary its rule declares and
points back to the file holding the rest. It never reads the prompt: nothing
it prints depends on what was typed, so no parser stands between it and the
turn.

Reads the rules where the project's config file puts them, and the set the
kit ships where it says nothing. Names the project's conventions collection
where the project keeps one — an absent collection simply goes unmentioned.
Needs nothing but `bash`.
