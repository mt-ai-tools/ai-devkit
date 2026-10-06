#!/usr/bin/env bash
# What the stand-in's turn-start hooks read from Claude Code's turn-start
# event — the session and the prompt the operator typed — and the answers they
# give back. Needs jq, for the reason the gate's event reader gives. Every
# function here is a transform. Sourced, never executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_PROMPT_EVENT:-}" ] || return 0
STAND_IN_LOADED_PROMPT_EVENT=1
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

# --- Answering.

# The answer that refuses the prompt: it never reaches the model, and the
# operator is shown the reason given, whole.
to_prompt_block_answer() {
  jq -cn --arg reason "$1" '{decision: "block", reason: $reason}'
}

# The answer that lets the prompt go on: the message the operator's terminal
# shows whole, every byte as given, and the note added to the model's
# context, since the model never sees the message.
to_prompt_answer() {
  jq -cn --arg message "$1" --arg note "$2" '{
    systemMessage: $message,
    hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $note}
  }'
}
