#!/usr/bin/env bash
# What the stand-in's before-tool hook reads from Claude Code's before-tool
# event — the session and the tool about to run — and the answers it gives
# back. Needs jq, for the reason the gate's event reader gives. Every function
# here is a transform. Sourced, never executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_PRE_TOOL_EVENT:-}" ] || return 0
STAND_IN_LOADED_PRE_TOOL_EVENT=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/session-id.sh"

# Claude Code's own name for its question tool, the box a question is asked
# in rather than in the reply. Claude Code fixes it, not the stand-in.
QUESTION_TOOL="AskUserQuestion"

# --- Reading the event.

# The name of the tool the event is about to run; nothing where it names
# none, the event not being JSON included.
to_tool_name() {
  jq -r '.tool_name // empty | strings' 2>/dev/null <<<"$1" || true
}

# True if the tool named is Claude Code's question tool.
is_question_tool() {
  [ "$1" = "$QUESTION_TOOL" ]
}

# The session id the event carries; a refusal on stderr and a non-zero status
# where it carries none that may name a file, the event not being JSON
# included.
to_tool_session() {
  local session
  session="$(jq -r '.session_id // empty | strings' 2>/dev/null <<<"$1")" || session=""
  if ! is_session_id "$session"; then
    refuse_tool_session_note >&2
    return 1
  fi
  printf '%s\n' "$session"
}

# --- Answering.

# The answer that refuses the tool: it does not run, and the model is handed
# the reason given in its place (seen live 2026-10-06, Claude Code 2.1.292;
# the operator's terminal shows the reason too, labelled as a hook error).
to_tool_deny_answer() {
  jq -cn --arg reason "$1" '{
    hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}
  }'
}

# The answer that lets the tool run as it would have and shows the operator
# the words given; the model never sees them. It carries no permission
# decision on purpose: "allow" would skip the permission prompt the tool
# would otherwise get, and this answer must change nothing about the run.
to_tool_note_answer() {
  jq -cn --arg message "$1" '{systemMessage: $message}'
}
