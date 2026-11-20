# injector

The start-of-turn briefing that puts the rules and shapes in front of the
agent.

It enforces nothing, and never lets a turn run without the rules and
shapes. It
never reads the prompt, so nothing it prints depends on what was typed.

Needs the rules and the shapes — the project's own where its config names
them, the sets the kit ships where it does not — and nothing but `bash`
and `awk`.
