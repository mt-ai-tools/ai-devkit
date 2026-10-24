# injector

Puts the rules in front of the agent at the start of every turn.

It enforces nothing. A turn it could not prepare is refused, with the
reason shown to the operator, rather than run without the rules. It
never reads the prompt, so nothing it prints depends on what was typed.

Reads the rules where the project's config file puts them, and the set
the kit ships where it says nothing. Needs nothing but `bash` and `awk`.
