#!/usr/bin/env bash
# Claude Code after-tool hook for the file-editing tools — the thin
# orchestrator that notes an exam owed: where a session edits what the
# stand-in judges by — its preset, its prompts or its model list — the
# session's exam owed is marked, with the file, whether the stand-in is on
# for the session or not. Every other edit, and every other tool, it leaves
# alone and unsaid.
#
# Per session and through Claude Code, never a git hook (the operator's call,
# 2026-10-06): the mark holds that session's step reports, and no other's.
# What it cannot see: an edit made through the shell, or by hand outside
# Claude Code, or in a session that does not load this hook. It never reads a
# shell command for what it might write, since what a command writes cannot
# be told from its text.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin after the
# tool ran, naming the tool and its input. A systemMessage shows the operator
# its words whole; printing nothing changes nothing about the run. The tool's
# name is checked here as well as where the hook is registered, so a
# registration that matches more tools notes only edits.
#
# Fails toward the operator once the tool is known to edit a file: where the
# edit cannot be checked or the mark cannot be written, the operator is told
# that no exam is asked for it. Before that it is silent, as the question
# hook is: a hook that cannot tell which tool it was handed must not speak up
# for every tool.
set -euo pipefail
# Errexit kept inside command substitutions; why beside the gate's own line.
shopt -s inherit_errexit

# Kept outside every function, for the trap below to read: the file every
# part's refusal is gathered in, and whether the tool edits a file.
reasons=""
recognised=""

# Armed before anything is loaded, as the gate's trap is and for the same
# reason: a part that cannot be loaded ends bash with an ordinary error and
# no ERR trap run.
tell_unnoted() {
  local status=$? why=""
  if [ -n "$reasons" ]; then
    why="$(cat "$reasons" 2>/dev/null || true)"
    rm -f "$reasons"
  fi
  [ "$status" -eq 0 ] && return
  [ -n "$recognised" ] || exit 0
  # Nothing below may end the trap before the operator is told.
  set +e
  to_edit_note_answer "$(edit_unnoted_note "$why")"
  exit 0
}
trap tell_unnoted EXIT

# Every part says why it refused on stderr; gathered here, it becomes the
# reason the operator is shown.
reasons="$(mktemp)"
exec 2>"$reasons"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/edit-event.sh"
. "$tool_root/lib/owed.sh"

# Every value below is resolved into a variable before use, never inline as
# an argument, for the reason the gate gives.
event="$(cat)"
tool="$(to_edit_tool "$event")"
is_edit_tool "$tool" || exit 0
recognised=1

session="$(to_edit_session "$event")"
path="$(to_edited_path "$event")"
path="$(get_canonical_path "$path")"
preset="$(get_config_path AIDK_STAND_IN)"
judged_lines="$(list_judgement_paths "$preset")"
readarray -t judged <<<"$judged_lines"
is_judgement_path "$path" "${judged[@]}" || exit 0

history="$(get_config_path AIDK_STAND_IN_HISTORY)"
mark="$(find_owed_mark "$history" "$session")"
now="$(get_owed_now)"
mark="$(with_owed_file "$mark" "$path" "$now")"
write_owed_mark "$history" "$session" "$mark"
