#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — tells a session that has grown past the
# size worth compacting so, at every turn until it is compacted.
#
# A session cannot see its own size, and a check it has to remember to run
# is run only where the work hands it a moment: between built steps, never
# in a long discussion. Asked at every turn instead, no session is missed,
# and a check run as the session's own tool would re-read its whole context
# each time only to learn its size; here it costs no context at all. Short
# of the line nothing is printed. What the session does with the note is the
# workflow's to say, not this hook's.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin, naming the
# session's transcript; stdout is added to the model's context before the
# turn begins. Never blocks a turn: a note is advice. Where the transcript
# cannot be named, the operator is told on stderr, with a status Claude Code
# shows without stopping the turn: a session never told it has grown long
# must not look like one still short.
set -euo pipefail
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/agent-event.sh"
. "$tool_root/../lib/readers/transcript.sh"
. "$tool_root/lib/words.sh"

# The size past which a session is worth compacting at its next clean point.
# Every reply re-reads the whole context, so a long session's late turns
# cost the most; well short of this size, a compaction would buy little for
# the detail it drops. Lowered from a quarter of a million on trial, to see
# what earlier compaction saves.
SESSION_COMPACT_AT=200000

event="$(cat)"
transcript="$(agent_event_field "$event" transcript_path)"
if [ -z "$transcript" ]; then
  compact_hook_no_transcript_note >&2
  exit 1
fi
# A session's first turn may come before its transcript is written; a
# session with nothing written yet is short.
[ -f "$transcript" ] || exit 0

size="$(last_reply_size "$transcript" false)"
[ "${size:-0}" -gt "$SESSION_COMPACT_AT" ] || exit 0
compact_hook_note "$size"
