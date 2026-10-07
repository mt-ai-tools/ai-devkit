#!/usr/bin/env bash
# What the skill hook reads from Claude Code's after-tool event and the answer
# it gives back. Needs jq, for the reason the gate's event reader gives. Every
# function here is a transform. Sourced, never executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_SKILL_EVENT:-}" ] || return 0
STAND_IN_LOADED_SKILL_EVENT=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/session-id.sh"

# The name of the skill the event loaded; nothing where the event is not a
# skill loading, or not JSON at all.
to_skill_loaded() {
  jq -r 'if .tool_name == "Skill" then (.tool_input.skill // "") else "" end | strings' \
    2>/dev/null <<<"$1" || true
}

# The session id the event carries; a refusal on stderr and a non-zero status
# where it carries none that may name a file, the event not being JSON
# included.
to_skill_session() {
  local session
  session="$(jq -r '.session_id // empty | strings' 2>/dev/null <<<"$1")" || session=""
  if ! is_session_id "$session"; then
    refuse_skill_session_note >&2
    return 1
  fi
  printf '%s\n' "$session"
}

# The words the skill was loaded with, as the model passed them; nothing where
# it passed none.
to_skill_args() {
  jq -r '.tool_input.args // "" | strings' 2>/dev/null <<<"$1" || true
}

# The hook's answer: the message the user's terminal shows whole, every byte
# as given, and the note the model reads in its place, since it never sees
# the message.
to_skill_answer() {
  jq -cn --arg message "$1" --arg note "$2" '{
    systemMessage: $message,
    hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $note}
  }'
}
