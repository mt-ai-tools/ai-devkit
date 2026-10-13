#!/usr/bin/env bash
# Says whether the session running it has grown worth compacting: "compact"
# with its size past the line below, "fine" with its size short of it.
#
#   session-size.sh [<transcript>]
#
# Run by a session at a clean point of a brief — its questions answered and
# written down, or a step committed and recorded — never mid-work: the
# session decides there, and only there, whether to stop and ask the operator
# to compact. A session cannot compact itself, and cannot see its own size;
# this reads it from the session's transcript.
#
# The size is what the last reply of the main conversation sent to the model:
# its own input, plus what was read from and written to the cache. A
# subagent's turns are left out, as they carry a context of their own. After
# a compaction the next reply is small again, so the answer follows it.
#
# Given no transcript, it finds the session's own by the id Claude Code hands
# every command it runs, under the folder Claude Code keeps transcripts in.
#
# Status: 0 when it answered, either way; 1 for a refusal. The line says which.
set -euo pipefail
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../lib/words.sh"

# The size past which a session is worth compacting at its next clean point.
# A quarter of a million: every reply re-reads the whole context, and in the
# kit's first project the turns past this size held most of a long session's
# tokens; well short of it, a compaction would buy little for the detail it
# drops.
SESSION_COMPACT_AT=250000

# Where Claude Code names the session to every command it starts, and where
# it keeps transcripts, one folder per project. Its own names, not ours.
SESSION_ID_VARIABLE="CLAUDE_CODE_SESSION_ID"
TRANSCRIPTS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"

refuse() {
  printf '%s' "$1" >&2
  exit 1
}

find_transcript() {
  local id="${!SESSION_ID_VARIABLE:-}" found
  [ -n "$id" ] || refuse "$(session_size_no_session_note "$SESSION_ID_VARIABLE")"$'\n'
  found="$(find "$TRANSCRIPTS_DIR" -maxdepth 2 -name "$id.jsonl" -print -quit 2>/dev/null || true)"
  [ -n "$found" ] || refuse "$(session_size_no_transcript_note "$id" "$TRANSCRIPTS_DIR")"$'\n'
  printf '%s' "$found"
}

# The context the main conversation's last reply carried; nothing before its
# first reply. A line that is not whole JSON — one being written as this
# reads — is passed over rather than failing the answer.
last_size() {
  jq -R -r 'fromjson? | select(.type == "assistant" and (.isSidechain | not))
    | .message.usage // empty
    | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' "$1" |
    tail -n 1
}

case "$#" in
  0) transcript="$(find_transcript)" ;;
  1) transcript="$1" ;;
  *) refuse "$(session_size_usage_note)"$'\n' ;;
esac

size="$(last_size "$transcript")"
size="${size:-0}"
if [ "$size" -gt "$SESSION_COMPACT_AT" ]; then
  session_size_compact_note "$size"
else
  session_size_fine_note "$size"
fi
