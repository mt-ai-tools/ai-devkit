#!/usr/bin/env bash
# What the stand-in's edit hook reads from Claude Code's after-tool event of
# a file-editing tool — the session, the tool and the file it edited — and
# the answer it gives back. Needs jq, for the reason the gate's event reader
# gives. Every function here is a transform. Sourced, never executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_EDIT_EVENT:-}" ] || return 0
STAND_IN_LOADED_EDIT_EVENT=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/session-id.sh"

# Claude Code's own file-editing tools, by its own names, and the field of
# each one's input naming the file it edits: the set its permission rules
# treat as editing (read off Claude Code 2.1.292). Claude Code fixes them,
# not the stand-in. A file written any other way, through the shell, is not
# among them, and no edit of it is ever seen.
EDIT_TOOLS='{"Edit": "file_path", "Write": "file_path", "MultiEdit": "file_path", "NotebookEdit": "notebook_path"}'

# --- Reading the event.

# The name of the tool the event ran; nothing where it names none, the event
# not being JSON included.
to_edit_tool() {
  jq -r '.tool_name // empty | strings' 2>/dev/null <<<"$1" || true
}

# True if the tool named is one of Claude Code's file-editing tools.
is_edit_tool() {
  jq -en --arg tool "$1" --argjson tools "$EDIT_TOOLS" '$tools | has($tool)' >/dev/null
}

# The session id the event carries; a refusal on stderr and a non-zero status
# where it carries none that may name a file, the event not being JSON
# included.
to_edit_session() {
  local session
  session="$(jq -r '.session_id // empty | strings' 2>/dev/null <<<"$1")" || session=""
  if ! is_session_id "$session"; then
    refuse_edit_session_note >&2
    return 1
  fi
  printf '%s\n' "$session"
}

# The file the tool edited, as its input names it, read from the folder the
# event says the session stood in where the name is not absolute; a refusal
# on stderr and a non-zero status where it names none.
to_edited_path() {
  local path
  path="$(jq -r --argjson tools "$EDIT_TOOLS" \
    '.tool_input[$tools[.tool_name]] // empty | strings' 2>/dev/null <<<"$1")" || path=""
  if [ -z "$path" ]; then
    refuse_edit_path_note >&2
    return 1
  fi
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s/%s\n' "$(jq -r '.cwd // empty | strings' <<<"$1")" "$path" ;;
  esac
}

# --- Answering.

# The answer that changes nothing about the tool's run and shows the operator
# the words given; the model never sees them.
to_edit_note_answer() {
  jq -cn --arg message "$1" '{systemMessage: $message}'
}
