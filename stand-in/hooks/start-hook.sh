#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — the thin orchestrator for the command
# that starts the stand-in. Typed with a brief's name, it switches the
# stand-in on for the session, takes the brief through the work organizer,
# and hands the model the preset's opener; with the session flag, it switches
# the stand-in on and takes nothing; bare, it shows the operator the
# organizer's list to pick from and changes nothing. Every other prompt it
# lets go untouched and unsaid.
#
# Why a hook and not the skill the command is offered by: the switch and the
# take are named for the session, and only the event carries its id; the
# model does not know it, and code, not the model, decides what is switched
# on and taken. The command is the only way a brief is taken, so whether it
# was is never a guess at what a prompt meant.
#
# Why the list goes through a hook's message and not through the model, as
# the organizer's own list does: a model asked to copy a list lost its last
# line in one run of six, while a systemMessage reaches the operator's
# terminal whole, exactly as written.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin, its prompt
# as typed, a skill's command included (seen live 2026-10-06, Claude Code
# 2.1.291: "/<name> <words>"). Answering {"decision":"block","reason":…}
# refuses the prompt: the model never sees it, and the operator is shown the
# reason whole. A systemMessage shows the operator its words whole; the
# additionalContext beside it is added to the model's context.
#
# Fails closed once the prompt is known to be the command: any part that
# refuses refuses the prompt, with every reason given, and takes back the
# switch this run wrote, so nothing is left switched on that the operator was
# told was not. Before that it fails open and silent: a hook that cannot tell
# whether a prompt is its command must not refuse every prompt of every
# session. The skill then finds no note, and tells the operator the hook did
# not act.
set -euo pipefail

# Kept outside every function, for the trap below to read: the file every
# part's refusal is gathered in, whether the prompt was the command, and the
# switch this run wrote, if it wrote one.
reasons=""
recognised=""
history=""
session=""
wrote_switch=""

# Armed before anything is loaded, as the gate's trap is and for the same
# reason: a part that cannot be loaded ends bash with an ordinary error and no
# ERR trap run. Every part is loaded before the prompt can be recognised, so
# where it was, the words and answers used here are there.
refuse_start() {
  local status=$? why="" left message
  if [ -n "$reasons" ]; then
    why="$(cat "$reasons" 2>/dev/null || true)"
    rm -f "$reasons"
  fi
  [ "$status" -eq 0 ] && return
  [ -n "$recognised" ] || exit 0
  # Nothing below may end the trap before the operator is answered.
  set +e
  message="$(start_refused_note "$why")"
  if [ -n "$wrote_switch" ]; then
    left="$(remove_switch "$history" "$session" 2>&1)" || message+=$'\n'"$(start_switch_left_line "$left")"
  fi
  to_prompt_block_answer "$message"
  exit 0
}
trap refuse_start EXIT

# Every part says why it refused on stderr; gathered here, it becomes the
# reason the operator is shown.
reasons="$(mktemp)"
exec 2>"$reasons"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/../lib/readers/header.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/prompt-event.sh"
. "$tool_root/lib/start-command.sh"
. "$tool_root/lib/switch.sh"
. "$tool_root/lib/briefs.sh"
. "$tool_root/lib/preset.sh"

# Found from this hook's own place in the kit, never from the project's
# layout: the kit names no project folder.
entry_skill="$tool_root/skills/start/SKILL.md"

# Bare: the organizer's list, shown whole; nothing written.
show_list() {
  local shown
  shown="$(get_organizer_list; printf x)"
  shown="${shown%x}"
  to_prompt_answer "$shown" "$(start_list_agent_note "$(printf '%s' "$shown" | awk 'END { print NR }')")"
}

# With the session flag: the switch, and nothing taken.
start_session() {
  local answer
  answer="$(to_prompt_answer "$(start_session_shown_note)" "$(start_session_agent_note)")"
  history="$(get_config_path AIDK_STAND_IN_HISTORY)"
  write_switch "$history" "$session"
  printf '%s\n' "$answer"
}

# With a brief: the switch first, then the take, and the switch taken back
# where the take is refused. The take is the one step another session can
# refuse, so it goes last, and all that stands before it is the stand-in's own
# file, which this run alone wrote and can remove. The other order would undo
# a take on a failed switch, through the organizer's free, which frees every
# brief the session holds, or its free-brief, which cannot tell this take
# from one the session already held. A switch that stood before this run is
# left standing: the session was on before it, and stays on.
#
# Everything that can be refused without changing anything — the opener, the
# answer — is made first, so a refusal there leaves nothing to take back, and
# nothing after the take can fail.
start_brief() {
  local brief="$1" preset opener answer existing
  history="$(get_config_path AIDK_STAND_IN_HISTORY)"
  preset="$(get_config_path AIDK_STAND_IN)"
  opener="$(read_opener "$preset")"
  answer="$(to_prompt_answer "$(start_brief_shown_note "$brief")" \
    "$(start_brief_agent_note "$brief" "$preset/$PRESET_OPENER_FILE" "$opener")")"
  existing="$(find_switch "$history" "$session")"
  write_switch "$history" "$session"
  [ -n "$existing" ] || wrote_switch=1
  take_brief "$brief" "$session"
  printf '%s\n' "$answer"
}

# Every value below is resolved into a variable before use, never inline as
# an argument, for the reason the gate gives.
event="$(cat)"
prompt="$(to_prompt_text "$event")"
command="$(read_header_fields "$entry_skill" name)"
[ -n "$command" ] || exit 1
is_start_command "$prompt" "$command" || exit 0
recognised=1

session="$(to_prompt_session "$event")"
request="$(to_start_request "$prompt" "$command")"
case "${request%%"$START_US"*}" in
  "$START_LIST") show_list ;;
  "$START_SESSION") start_session ;;
  "$START_BRIEF") start_brief "${request#*"$START_US"}" ;;
esac
