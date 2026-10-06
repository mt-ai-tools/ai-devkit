#!/usr/bin/env bash
# Claude Code after-tool hook for the Skill tool — the thin orchestrator that
# shows the user what the stand-in's two skills ask for: the list of the
# questions it settled without them, or one of those brought back in full.
# Silent for every other skill. One hook for both, as the organizer has one
# for its skill: each skill is told apart by the name its own file declares.
#
# Why through a hook and not through the model: a hook's systemMessage
# reaches the user's terminal whole, exactly as written, with no model in
# between; a model asked to copy a list has dropped its last line (the
# organizer's skill, one run in six). The model never sees the message, so
# it is handed a note in additionalContext saying what was shown; a reopened
# question's note also hands it the question, open again, to ask.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin; the answer
# is JSON on stdout. A refusal — words it does not understand, a number no
# settled question has, a log it cannot read — is shown to the user as the
# answer, never left silent.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/../lib/readers/header.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/skill-event.sh"
. "$tool_root/lib/question-log.sh"
. "$tool_root/lib/settled.sh"
. "$tool_root/lib/reopen.sh"

# Both found from this hook's own place in the kit, never from the project's
# layout: the kit names no project folder.
settled_skill="$tool_root/skills/settled/SKILL.md"
reopen_skill="$tool_root/skills/reopen/SKILL.md"

# The skill's name as its own file declares it, read rather than written here
# a second time, so the name Claude Code loads it by and the name the hook
# answers to cannot drift apart. A name that cannot be read is an error, not
# "some other skill": silence would leave every load of it with nothing shown
# and no reason.
own_name() {
  local name
  name="$(read_header_fields "$1" name 2>/dev/null)" || name=""
  if [ -z "$name" ]; then
    skill_name_unreadable_note "$1" >&2
    exit 1
  fi
  printf '%s\n' "$name"
}

# Show the user the refusal the step wrote to the file given, and tell the
# model so.
answer_refused() {
  to_skill_answer "$(cat "$1")" "$(skill_refusal_shown_note)"
  rm -f "$1"
  exit 0
}

# The settled lines of the log, left in settled; or the refusal shown. Run in
# the hook's own shell, never in a command substitution, where a refusal's
# exit would end only the substitution and its answer be taken for lines.
read_settled() {
  local history lines
  history="$(get_config_path AIDK_STAND_IN_HISTORY 2>"$why")" || answer_refused "$why"
  lines="$(list_log_lines "$(to_log_dir "$history")" 2>"$why")" || answer_refused "$why"
  settled="$(to_settled_lines "$lines")"
}

show_settled() {
  local scope today shown
  scope="$(to_settled_scope "$args" 2>"$why")" || answer_refused "$why"
  read_settled
  today="$(date +%Y-%m-%d)"
  # The trailing "x" keeps the list's final newline, which a command
  # substitution would strip: the user is shown every byte of it.
  shown="$(format_settled_list "$settled" "$today" "$scope"; printf x)"
  shown="${shown%x}"
  to_skill_answer "$shown" "$(skill_settled_shown_note "$(printf '%s' "$shown" | awk 'END { print NR }')")"
}

# The words are read before the log, so a request it cannot understand is
# refused as such, whatever the log holds.
show_reopened() {
  local request line shown
  request="$(to_reopen_request "$args" 2>"$why")" || answer_refused "$why"
  read_settled
  line="$(to_reopened_line "$settled" "$(jq -r '.number' <<<"$request")" 2>"$why")" || answer_refused "$why"
  shown="$(format_reopened "$line" "$(jq -r '.exchange' <<<"$request")"; printf x)"
  shown="${shown%x}"
  to_skill_answer "$shown" "$(format_reopened_agent_note "$line")"
}

event="$(cat)"
loaded="$(to_skill_loaded "$event")"
[ -n "$loaded" ] || exit 0
settled_name="$(own_name "$settled_skill")"
reopen_name="$(own_name "$reopen_skill")"
args="$(to_skill_args "$event")"
settled=""
why="$(mktemp)"
trap 'rm -f "$why"' EXIT

case "$loaded" in
  "$settled_name") show_settled ;;
  "$reopen_name") show_reopened ;;
esac
