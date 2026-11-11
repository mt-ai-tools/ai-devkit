#!/usr/bin/env bash
# How big a conversation has grown, read from its transcript, in one place:
# the session's compact note and the builder's size hook ask the same question
# of two transcripts. Needs jq. Sourced, never executed.

# How much of a transcript's end is read first. Its last reply sits near the
# end, and the session's note reads it at every turn: the whole of a long
# session's transcript, a hundred megabytes and more, took seconds a turn.
# Only where later lines outgrow this, a large tool result after the reply,
# is the whole read.
TRANSCRIPT_TAIL_BYTES=2000000

# The context the last reply carried: its own input, plus what was read from
# and written to the cache; nothing before the first reply. Only replies
# marked as a subagent's count where the second argument is "true", only the
# main conversation's where it is "false": a session's transcript also holds
# its subagents' turns, which carry a context of their own, and a subagent's
# own transcript holds nothing else. A line that is not whole JSON — one being
# written as this reads, or the one the end's cut falls inside — is passed
# over rather than failing the answer.
last_reply_size() {
  local size
  size="$(tail -c "$TRANSCRIPT_TAIL_BYTES" "$1" | reply_sizes "$2" | tail -n 1)"
  if [ -z "$size" ] && [ "$(wc -c <"$1")" -gt "$TRANSCRIPT_TAIL_BYTES" ]; then
    size="$(reply_sizes "$2" <"$1" | tail -n 1)"
  fi
  printf '%s' "$size"
}

reply_sizes() {
  jq -R -r --argjson sidechain "$1" 'fromjson? | select(.type == "assistant" and ((.isSidechain // false) == $sidechain))
    | .message.usage // empty
    | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)'
}
