#!/usr/bin/env bash
# What the stand-in's session-end hook reads from Claude Code's session-end
# event: the session it belongs to, and nothing else. Needs jq, for the reason
# the gate's event reader gives. Every function here is a transform. Sourced,
# never executed.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/session-id.sh"

# The session id the event carries; a refusal on stderr and a non-zero status
# where it carries none that may name a file, the event not being JSON
# included.
to_end_session() {
  local session
  session="$(jq -r '.session_id // empty | strings' 2>/dev/null <<<"$1")" || session=""
  if ! is_session_id "$session"; then
    refuse_end_session_note >&2
    return 1
  fi
  printf '%s\n' "$session"
}
