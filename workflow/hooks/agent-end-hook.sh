#!/usr/bin/env bash
# Claude Code subagent-end hook — notes that an agent of a kind that reports
# once has reported, so the message hook can refuse it more work.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin, naming the
# agent that ended and its type. Nothing is printed for the model. A session
# id that cannot be used as a name is told to the operator on stderr, with a
# status Claude Code shows without stopping anything.
set -euo pipefail
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/agent-event.sh"
. "$tool_root/lib/finished.sh"
. "$tool_root/lib/words.sh"

event="$(cat)"
is_one_report_agent "$(agent_event_field "$event" agent_type)" || exit 0

session="$(agent_event_field "$event" session_id)"
list="$(finished_list "$session")" || { bad_session_note "$session" >&2; exit 1; }
mkdir -p "$(dirname "$list")"
agent_event_field "$event" agent_id >>"$list"
