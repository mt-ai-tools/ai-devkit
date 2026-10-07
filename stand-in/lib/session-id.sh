#!/usr/bin/env bash
# Whether a value may be taken as a session id, in one place: every hook of
# the stand-in's reads one off its event, and each names files with it.
# Sourced, never executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_SESSION_ID:-}" ] || return 0
STAND_IN_LOADED_SESSION_ID=1

# The variable Claude Code sets, in the environment of every command the
# agent runs, to the session's id: the id its hooks' events carry (seen live
# 2026-10-07, Claude Code 2.1.292). The one way a command the agent runs can
# tell which session it runs in.
SESSION_ID_VARIABLE="CLAUDE_CODE_SESSION_ID"

# True if the value is a session id as Claude Code hands it out: letters,
# digits and hyphens. The id names the session's switch and its record, so
# nothing else may reach a path: a slash or a dot could address a file outside
# the stand-in's folders. The organizer checks its own ids the same way, for
# its own paths; neither tool reads the other's.
is_session_id() {
  [[ "$1" =~ ^[A-Za-z0-9-]+$ ]]
}
