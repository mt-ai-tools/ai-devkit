#!/usr/bin/env bash
# How big a conversation has grown, read from its transcript, in one place:
# the session's size check and the builder's size hook ask the same question
# of two transcripts. Needs jq. Sourced, never executed.

# The context the last reply carried: its own input, plus what was read from
# and written to the cache; nothing before the first reply. Only replies
# marked as a subagent's count where the second argument is "true", only the
# main conversation's where it is "false": a session's transcript also holds
# its subagents' turns, which carry a context of their own, and a subagent's
# own transcript holds nothing else. A line that is not whole JSON — one being
# written as this reads — is passed over rather than failing the answer.
last_reply_size() {
  jq -R -r --argjson sidechain "$2" 'fromjson? | select(.type == "assistant" and ((.isSidechain // false) == $sidechain))
    | .message.usage // empty
    | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' "$1" |
    tail -n 1
}
