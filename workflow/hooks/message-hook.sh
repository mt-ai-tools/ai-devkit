#!/usr/bin/env bash
# Claude Code before-tool hook for the tool that messages an agent — refuses
# a message to an agent that reports once and already has.
#
# An answered question, a correction or the next piece of work each go to a
# fresh agent: one sent more work drags its whole earlier run into the next,
# which costs more and reads worse. The written workflow says so; this makes
# it hold.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin; a refusal
# goes back as JSON on stdout, with its reason, which the session reads.
# Silent for every other message.
set -euo pipefail
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/agent-event.sh"
. "$tool_root/lib/finished.sh"
. "$tool_root/lib/words.sh"

event="$(cat)"
to="$(agent_event_tool_input "$event" to)"
[ -n "$to" ] || exit 0

list="$(finished_list "$(agent_event_field "$event" session_id)")" || exit 0
[ -f "$list" ] || exit 0
grep -qxF -- "$to" "$list" || exit 0

jq -n --arg reason "$(finished_agent_note "$to")" '{
  hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}
}'
