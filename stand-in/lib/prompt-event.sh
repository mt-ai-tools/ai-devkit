#!/usr/bin/env bash
# What the answer hook reads from Claude Code's turn-start event: the session
# and the prompt the operator typed. Needs jq, for the reason the gate's event
# reader gives. Every function here is a transform. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/session-id.sh"

# The session id the event carries; a refusal on stderr and a non-zero status
# where it carries none that may name a file, the event not being JSON
# included.
to_prompt_session() {
  local session
  session="$(jq -r '.session_id // empty | strings' 2>/dev/null <<<"$1")" || session=""
  if ! is_session_id "$session"; then
    refuse_prompt_session_note >&2
    return 1
  fi
  printf '%s\n' "$session"
}

# The prompt the event carries, as typed; a refusal on stderr and a non-zero
# status where it carries none.
to_prompt_text() {
  local prompt
  if ! prompt="$(jq -er '.prompt | strings' 2>/dev/null <<<"$1")"; then
    refuse_prompt_text_note >&2
    return 1
  fi
  printf '%s\n' "$prompt"
}
