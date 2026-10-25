# injector

The start-of-turn briefing that puts the rules in front of the agent.

It enforces nothing, and never lets a turn run without the rules. It
never reads the prompt, so nothing it prints depends on what was typed.

Needs the rules — the project's own where its config names them, the set
the kit ships where it does not — and nothing but `bash` and `awk`.
