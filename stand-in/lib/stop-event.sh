#!/usr/bin/env bash
# What the gate reads from Claude Code's end-of-reply event, and the answers
# it gives back. Needs jq, for the reason the organizer's hooks give: an event
# is JSON written by Claude Code, and parsing it by hand is how an escaped
# character slips through. Every function here is a transform. Sourced, never
# executed.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# --- Reading the event.

# The event, compact, where it is one JSON object; a refusal on stderr and a
# non-zero status otherwise.
refuse_unreadable_event() {
  local event
  if ! event="$(jq -ce 'select(type == "object")' 2>/dev/null <<<"$1")" || [ -z "$event" ]; then
    refuse_event_unreadable_note >&2
    return 1
  fi
  printf '%s\n' "$event"
}

# True if the value is a session id as Claude Code hands it out: letters,
# digits and hyphens. The id names the session's switch and its record, so
# nothing else may reach a path: a slash or a dot could address a file outside
# the stand-in's folders. The organizer checks its own ids the same way, for
# its own paths; neither tool reads the other's.
is_session_id() {
  [[ "$1" =~ ^[A-Za-z0-9-]+$ ]]
}

# The session id the event carries; a refusal on stderr and a non-zero status
# where it carries none that may name a file.
to_event_session() {
  local session
  session="$(jq -r '.session_id // empty | strings' <<<"$1")"
  if ! is_session_id "$session"; then
    refuse_event_session_note >&2
    return 1
  fi
  printf '%s\n' "$session"
}

# The reply the event carries, as the agent wrote it, for the reader alone;
# a refusal on stderr and a non-zero status where it carries none. Read off
# the event, never off the conversation's record: the gate reads no
# conversation itself, and a reply it was not handed is not one it judges.
to_event_reply() {
  local reply
  if ! reply="$(jq -er '.last_assistant_message | strings' <<<"$1")" || [ -z "$reply" ]; then
    refuse_event_reply_note >&2
    return 1
  fi
  printf '%s\n' "$reply"
}

# True if this stop follows a reply the gate held, rather than a new turn of
# the operator's: Claude Code marks every stop after a held one.
is_event_continuation() {
  jq -e '.stop_hook_active == true' >/dev/null <<<"$1"
}

# --- Answering.

# The answer that holds the reply and hands the agent the words given as its
# next instruction.
to_block_answer() {
  jq -cn --arg reason "$1" '{decision: "block", reason: $reason}'
}

# The answer that lets the reply stop and shows the operator the words given;
# the agent never sees them.
to_operator_answer() {
  jq -cn --arg message "$1" '{systemMessage: $message}'
}
