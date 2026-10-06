#!/usr/bin/env bash
# Claude Code before-tool hook for the question tool — the thin orchestrator
# that keeps questions in the reply: in a session the stand-in is switched on
# for, the question box is refused, and the agent is told, in the stand-in's
# words, to ask in its reply instead. In every other session, and for every
# other tool, it does nothing at all, and the box works as before.
#
# Why: the gate reads only the reply, so a question asked in the box would
# pass it unseen, and reach the operator unchecked, unsorted and unlogged
# (settled 2026-10-06, found in the brief's closing sweep). Code decides, from
# the switch alone; no model is asked.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin, naming the
# tool about to run. Answering a permission decision of "deny" with a reason
# stops the tool, and the model is handed the reason in its place (proved live
# 2026-10-06, Claude Code 2.1.292). Printing nothing lets the tool run as it
# would have. The tool's name is checked here as well as where the hook is
# registered, so a registration that matches more tools refuses only the box.
#
# Fails open, as the start hook does before it knows the prompt is its
# command, and as the gate fails toward the operator: where whether the
# stand-in is on cannot be told, the box is let through and the operator is
# told why. Refusing it there would refuse the box in every session, the ones
# the stand-in was never on for included; and the gate, unable to tell the
# switch either, brings every reply to the operator unjudged, so a question
# kept out of the box would reach them no better checked than one in it.
# Before the tool is known to be the box, any failure is silent: a hook that
# cannot tell which tool it was handed must not speak up for every tool.
set -euo pipefail

# Kept outside every function, for the trap below to read: the file every
# part's refusal is gathered in, and whether the tool is the question box.
reasons=""
recognised=""

# Armed before anything is loaded, as the gate's trap is and for the same
# reason: a part that cannot be loaded ends bash with an ordinary error and no
# ERR trap run. Every part is loaded before the tool can be recognised, so
# where it was, the words and answers used here are there.
let_through() {
  local status=$? why=""
  if [ -n "$reasons" ]; then
    why="$(cat "$reasons" 2>/dev/null || true)"
    rm -f "$reasons"
  fi
  [ "$status" -eq 0 ] && return
  [ -n "$recognised" ] || exit 0
  # Nothing below may end the trap before the operator is told.
  set +e
  to_tool_note_answer "$(question_box_unjudged_note "$why")"
  exit 0
}
trap let_through EXIT

# Every part says why it refused on stderr; gathered here, it becomes the
# reason the operator is shown.
reasons="$(mktemp)"
exec 2>"$reasons"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/pre-tool-event.sh"
. "$tool_root/lib/switch.sh"

# Every value below is resolved into a variable before use, never inline as
# an argument, for the reason the gate gives.
event="$(cat)"
tool="$(to_tool_name "$event")"
is_question_tool "$tool" || exit 0
recognised=1

session="$(to_tool_session "$event")"
history="$(get_config_path AIDK_STAND_IN_HISTORY)"
switch="$(find_switch "$history" "$session")"
[ -n "$switch" ] || exit 0

to_tool_deny_answer "$(question_box_refused_note "$tool")"
