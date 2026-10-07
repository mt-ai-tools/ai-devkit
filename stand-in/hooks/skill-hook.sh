#!/usr/bin/env bash
# Claude Code after-tool hook for the Skill tool — the thin orchestrator that
# shows the user what the stand-in's two skills ask for: the list of the
# questions it settled without them, or one of those, a decision a round's
# list laid out before building, or a proposal the agent dropped under a
# challenge, brought back in full. A question brought back marks the
# session's record, so its next question reaches the user, and its own line
# in the log, where the trial's fall-back counts it; the reopen that sends a
# kind back to the trial says so under the question, once.
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
# answer, never left silent. So is a reopen whose mark cannot be made.
set -euo pipefail
# Errexit kept inside command substitutions; why beside the gate's own line.
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/../lib/readers/header.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/skill-event.sh"
. "$tool_root/lib/question-log.sh"
. "$tool_root/lib/switch.sh"
. "$tool_root/lib/record.sh"
. "$tool_root/lib/settled.sh"
. "$tool_root/lib/reopen.sh"
. "$tool_root/lib/trial.sh"

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

# The stand-in's working folder, left in history, every line of the log, left
# in logged, and the settled ones, left in settled; or the refusal shown. Run in the hook's own shell, never in a
# command substitution, where a refusal's exit would end only the
# substitution and its answer be taken for lines.
read_settled() {
  history="$(get_config_path AIDK_STAND_IN_HISTORY 2>"$why")" || answer_refused "$why"
  logged="$(list_log_lines "$(to_log_dir "$history")" 2>"$why")" || answer_refused "$why"
  settled="$(to_settled_lines "$logged")"
}

show_settled() {
  local scope today every=false shown
  scope="$(to_settled_scope "$args" 2>"$why")" || answer_refused "$why"
  read_settled
  today="$(date +%Y-%m-%d)"
  ! is_every_kind_on_trial "$history" || every=true
  # The trailing "x" keeps the list's final newline, which a command
  # substitution would strip: the user is shown every byte of it.
  shown="$(format_settled_list "$settled" "$today" "$scope" "$every"; printf x)"
  shown="${shown%x}"
  to_skill_answer "$shown" "$(skill_settled_shown_note "$(printf '%s' "$shown" | awk 'END { print NR }')")"
}

# Mark the session's record with the number reopened, where the stand-in is
# on for the session: the gate then brings the session's next question to the
# user whatever its kind and route (settled 2026-10-06), since asked again it
# would otherwise pass the gate as any question, and once its kind is switched
# be settled without them a second time. A mark that cannot be made refuses
# the reopen whole, for the same reason. Where the stand-in is off, the gate
# reads nothing of the session, the question reaches the user as the agent
# asks it, and nothing is marked.
mark_reopened() {
  local number="$1" session history switch file record
  session="$(to_skill_session "$event" 2>"$why")" || refuse_unmarked "$number"
  history="$(get_config_path AIDK_STAND_IN_HISTORY 2>"$why")" || refuse_unmarked "$number"
  switch="$(find_switch "$history" "$session" 2>"$why")" || refuse_unmarked "$number"
  [ -n "$switch" ] || return 0
  file="$(to_record_path "$history" "$session")"
  record="$(read_session_record "$file" 2>"$why")" || refuse_unmarked "$number"
  record="$(with_reopened "$record" "$number")"
  write_session_record "$file" "$record" 2>"$why" || refuse_unmarked "$number"
}

# Mark the line numbered so in the log as reopened, wherever the stand-in is
# on or off: the reopen is the user's say on a decision, and the trial's
# fall-back is worked out from the log each time it is asked (settled
# 2026-10-01/02, decision 9), so a reopen the log does not hold could never
# send a kind back. A mark that cannot be written refuses the reopen whole,
# for the same reason.
mark_log_reopened() {
  local number="$1" reason
  if ! write_log_reopened "$(to_log_dir "$history")" "$number" "$(get_log_now)" 2>"$why"; then
    reason="$(cat "$why")"
    reopen_unlogged_note "$number" "$reason" >"$why"
    answer_refused "$why"
  fi
}

# The notice that this reopen sent its kind back to the trial, given the
# line reopened; nothing where it did not: the line was no decision settled
# alone, its kind holds no yes, or the count was reached before or not yet.
# Read from the log as the reopen left it, against the lines read before it.
# Where it cannot be told, the user is told that instead: a notice lost here
# is never given again.
find_fallback_notice() {
  local line="$1" kind given after reason
  is_settled_line "$line" || return 0
  kind="$(jq -r '.kind // ""' <<<"$line")"
  is_trust_kind "$kind" || return 0
  if ! given="$(read_trust_given "$history" "$kind" 2>"$why")" \
    || ! after="$(list_log_lines "$(to_log_dir "$history")" 2>"$why")"; then
    reason="$(cat "$why")"
    trial_fallback_unknown_line "$reason"
    return 0
  fi
  [ -n "$given" ] || return 0
  derive_fallback_notice "$logged" "$after" "$kind" "$given"
}

# Show the user that the question numbered so was not reopened, with the
# reason the failing part wrote, and tell the model so.
refuse_unmarked() {
  local reason
  reason="$(cat "$why")"
  reopen_unmarked_note "$1" "$reason" >"$why"
  answer_refused "$why"
}

# The words are read before the log, so a request it cannot understand is
# refused as such, whatever the log holds. What may be reopened is what the
# operator was shown as a decision: a settled question, or one a round's list
# laid out before building.
show_reopened() {
  local request number reopenable line listed=false exchange shown note notice
  request="$(to_reopen_request "$args" 2>"$why")" || answer_refused "$why"
  number="$(jq -r '.number' <<<"$request")"
  read_settled
  reopenable="$(to_reopenable_lines "$logged")"
  line="$(to_reopened_line "$reopenable" "$number" 2>"$why")" || answer_refused "$why"
  ! is_round_listed "$logged" "$number" || listed=true
  # Made before anything is marked, and refused as any other step is: a
  # question that cannot be shown is never reopened behind the user's back.
  # The trailing "x" keeps the last newline, which a command substitution
  # would strip.
  exchange="$(jq -r '.exchange' <<<"$request")"
  shown="$(format_reopened "$line" "$exchange" 2>"$why" && printf x)" || answer_refused "$why"
  shown="${shown%x}"
  note="$(format_reopened_agent_note "$line" "$listed" 2>"$why")" || answer_refused "$why"
  mark_reopened "$number"
  mark_log_reopened "$number"
  notice="$(find_fallback_notice "$line")"
  [ -z "$notice" ] || shown+="$notice"$'\n'
  to_skill_answer "$shown" "$note"
}

event="$(cat)"
loaded="$(to_skill_loaded "$event")"
[ -n "$loaded" ] || exit 0
settled_name="$(own_name "$settled_skill")"
reopen_name="$(own_name "$reopen_skill")"
args="$(to_skill_args "$event")"
settled=""
logged=""
history=""
why="$(mktemp)"
trap 'rm -f "$why"' EXIT

case "$loaded" in
  "$settled_name") show_settled ;;
  "$reopen_name") show_reopened ;;
esac
