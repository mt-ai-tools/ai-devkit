#!/usr/bin/env bash
# Whether a value may be taken as a session id, in one place: every hook of
# the stand-in's reads one off its event, and each names files with it.
# Sourced, never executed.

# True if the value is a session id as Claude Code hands it out: letters,
# digits and hyphens. The id names the session's switch and its record, so
# nothing else may reach a path: a slash or a dot could address a file outside
# the stand-in's folders. The organizer checks its own ids the same way, for
# its own paths; neither tool reads the other's.
is_session_id() {
  [[ "$1" =~ ^[A-Za-z0-9-]+$ ]]
}
