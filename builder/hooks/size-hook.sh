#!/usr/bin/env bash
# Claude Code after-tool hook — tells a builder that has grown long to stop.
#
# Every turn re-reads the whole context, so a builder's late turns cost the
# most, and a long context also reads worse: a fresh builder handed what is
# left does the rest cheaper and better. A builder cannot see its own size;
# this reads it from the builder's own transcript after each of its tools,
# and past the line below hands it a note, again after every tool, until it
# stops. The note only advises: an edit is never refused, so a builder stops
# where the tests it touched pass, as its own file says, not mid-change.
#
# Silent for the session and for every other agent: only the agent whose
# name the builder's own file declares is measured.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin; the note
# goes back as JSON on stdout, which Claude Code shows the agent that ran the
# tool. Where the builder's transcript cannot be found, the operator is told
# on stderr, with a status Claude Code shows without stopping the builder:
# a builder never told it has grown long must not look like one still short.
set -euo pipefail
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/header.sh"
. "$tool_root/../lib/readers/agent-event.sh"
. "$tool_root/lib/transcript.sh"
. "$tool_root/lib/words.sh"

# The context past which a builder is told to stop. Builders' cost bends
# here: on the kit's own history, runs past it held most of what building
# cost, mostly spent re-reading what they had already read.
BUILDER_LONG_AT=200000

event="$(cat)"
agent_type="$(agent_event_field "$event" agent_type)"
[ -n "$agent_type" ] || exit 0

# Read from the builder's own file rather than written here a second time,
# so the name Claude Code starts it by and the name measured cannot drift.
own="$(read_header_fields "$tool_root/agents/builder.md" name)"
[ "$agent_type" = "$own" ] || exit 0

transcript="$(agent_event_transcript "$event")"
if [ ! -f "$transcript" ]; then
  size_hook_no_transcript_note "$transcript" >&2
  exit 1
fi

size="$(last_reply_size "$transcript" true)"
[ "${size:-0}" -gt "$BUILDER_LONG_AT" ] || exit 0

jq -n --arg note "$(size_hook_long_note "$size")" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $note}}'
