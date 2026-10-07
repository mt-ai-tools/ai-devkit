#!/usr/bin/env bash
# The exam's judging: what a test case expects of a replay, and whether the
# replay gave it, decided in code from the case's header and the forms the
# replayed parts gave, never from a model's words. Every function here is a
# transform. Sourced, never executed.
#
# A case is replayed through every part whose answer code decides from
# (settled 2026-10-06, decision 7): the reader, the rules and conventions
# check, the sorter and the route for a question; the reader, the step's
# labeller and the step go for a step's report. The parts that only write for
# the operator — the summary, the round's list, the cold second reading — are
# not, since nothing is decided from them. Each case is checked for four
# things: the reader read it as what it is; the check found what the case
# says it must; the sorter gave the case's kind; and the route sent it where
# the operator would.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_EXAM:-}" ] || return 0
STAND_IN_LOADED_EXAM=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/preset.sh"
. "$(dirname "${BASH_SOURCE[0]}")/step-go.sh"
. "$(dirname "${BASH_SOURCE[0]}")/exam-results.sh"

# The entry's command that runs the exam, as the agent types it after the
# entry's path.
EXAM_COMMAND="exam"

# How many times each case is replayed (settled with the operator
# 2026-10-07): the models answer differently from run to run — two real
# exams in a row on an unchanged stand-in gave different results, both seeds
# failing, then one passing — so one replay is a coin toss, and a case is
# judged on the most of its replays. Odd, so its replays never tie; each
# replay asks every part again, so raising it costs that many calls a case.
EXAM_REPLAYS=3

# Where a replayed case was sent: back to the agent, to the operator, or
# settled by the stand-in alone once its kind is through the trial. A seed
# case names one of the three as its route.
EXAM_TO_AGENT="agent"
EXAM_TO_OPERATOR="operator"
EXAM_ALONE="alone"
EXAM_ROUTES="[\"$EXAM_TO_AGENT\", \"$EXAM_TO_OPERATOR\", \"$EXAM_ALONE\"]"

# The findings a case may expect of the rules and conventions check, by the
# names of the check's own fields, as the seed cases write them.
EXAM_FINDINGS='["breaks", "miscalled", "explains_code"]'

# --- What a case expects.

# Why the case cannot be judged, in words; nothing where it can. A case holds
# a reply, and says where it must be sent or whether the operator picked the
# option recommended; a route or a finding it names must be one the exam
# knows. A case that cannot be judged fails, never passes unread.
derive_case_problem() {
  local case="$1" route picked finding
  if [ -z "$(jq -r '.reply' <<<"$case")" ]; then
    exam_case_no_reply_words
    return 0
  fi
  route="$(jq -r '.route' <<<"$case")"
  if [ -n "$route" ] && ! jq -e --arg route "$route" 'index($route) != null' >/dev/null <<<"$EXAM_ROUTES"; then
    exam_case_bad_route_words "$route"
    return 0
  fi
  picked="$(jq -r '.picked_recommended' <<<"$case")"
  if [ -z "$route" ] && [ "$picked" != "$(case_yes_words)" ] && [ "$picked" != "$(case_no_words)" ]; then
    exam_case_no_expectation_words
    return 0
  fi
  finding="$(jq -r --argjson known "$EXAM_FINDINGS" '[.findings[] | select(. as $f | $known | index($f) | not)][0] // empty' <<<"$case")"
  [ -z "$finding" ] || exam_case_bad_finding_words "$finding"
}

# True if the case is a step's report, given the name of the preset's kind
# whose route is the step go, empty where it has none. A case keeps the kind
# it was sorted as when asked, and a step's report was logged under the go's
# kind, so that is the one thing that tells it from a question.
is_step_case() {
  [ -n "$2" ] && [ "$(jq -r '.kind' <<<"$1")" = "$2" ]
}

# The kind the case names for the sorter to give; nothing where it names none
# or the log kept none.
to_case_kind() {
  jq -r --arg unknown "$(case_kind_unknown_words)" '.kind | select(. != "" and . != $unknown)' <<<"$1"
}

# --- Where a replay was sent.

# The route a question's replay takes, as the exam names it, given the route
# derive_route gave. The ladder and the light check climb on the agent's
# later replies, which no case holds, so their answer is taken as held: what
# would then stand without the operator is what the exam must catch.
to_exam_route() {
  case "$1" in
    agent) printf '%s\n' "$EXAM_TO_AGENT" ;;
    operator) printf '%s\n' "$EXAM_TO_OPERATOR" ;;
    *) printf '%s\n' "$EXAM_ALONE" ;;
  esac
}

# The route a step's report's replay takes, as the exam names it, given what
# derive_step_go gave next.
to_exam_step_route() {
  case "$1" in
    "$STEP_NEXT_AGENT") printf '%s\n' "$EXAM_TO_AGENT" ;;
    "$STEP_NEXT_OPERATOR") printf '%s\n' "$EXAM_TO_OPERATOR" ;;
    *) printf '%s\n' "$EXAM_ALONE" ;;
  esac
}

# --- The faults a replay can show, one line each; nothing where none.

# The reader read it as what the case is, given whether it is a step's report
# and the reader's form.
derive_reading_fault() {
  local step="$1" form="$2"
  if [ "$step" = true ]; then
    jq -e '.ends_step and (.asks_operator | not)' >/dev/null <<<"$form" || exam_misread_fault "$(exam_step_words)"
  else
    jq -e '.asks_operator' >/dev/null <<<"$form" || exam_misread_fault "$(exam_question_words)"
  fi
}

# The rules and conventions check found every kind of finding the case
# expects and named at least one of the entries it says are broken, given the
# case and the check's answer. A finding the case does not name is no fault:
# it is the route that shows whether the question was sent where the
# operator sent it.
#
# Any one listed entry is enough (settled with the operator 2026-10-07): a
# check that stopped the agent for the right reason but named one of two
# entries did its job, and failing it would block every change to the
# stand-in over a harmless difference. Every kind of finding stays required:
# that is what still catches a broken check, as the crew seed showed when the
# check missed that a sentence explained code while a challenge still sent
# the question back.
derive_checker_faults() {
  local case="$1" checked="$2" finding entry
  while IFS= read -r finding; do
    [ -n "$finding" ] || continue
    jq -e --arg f "$finding" 'if $f == "explains_code" then .explains_code else (.[$f] | length > 0) end' \
      >/dev/null <<<"$checked" || { exam_finding_missing_fault "$finding"; printf '\n'; }
  done < <(jq -r '.findings[]' <<<"$case")
  if jq -e '.breaks | length > 0' >/dev/null <<<"$case" \
    && ! jq -e --argjson listed "$(jq -c '.breaks' <<<"$case")" \
      'any(.breaks[]; .entry as $e | $listed | index($e) != null)' >/dev/null <<<"$checked"; then
    exam_breaks_none_fault "$(jq -r '.breaks | join(", ")' <<<"$case")"
  fi
}

# The sorter gave the case's kind, given the case and the sorter's answer;
# nothing to check where the case names none.
derive_kind_fault() {
  local kind sorted
  kind="$(to_case_kind "$1")"
  [ -n "$kind" ] || return 0
  sorted="$(jq -r '.kind' <<<"$2")"
  [ "$sorted" = "$kind" ] || exam_kind_fault "$sorted" "$kind"
}

# The route sent the case where the operator would (decision 7), given the
# case and the route the replay took. How a case says where that is was
# chosen building the exam (2026-10-07), from its header alone:
#
# - A case naming its route, as the seed cases do, is sent exactly there: the
#   operator said where it belonged, and back to the agent is where a
#   question that breaks an entry goes.
# - A case whose operator did not pick the option the agent recommended must
#   never be settled without them. Sent to them, or back to the agent, it
#   passes: either way it comes back through the gate before anything
#   stands, and nothing is decided against their answer.
# - A case whose operator picked the option recommended passes wherever it is
#   sent: settled alone, it stands as they chose; brought to them, or sent
#   back, it costs a turn and decides nothing against them. How often it
#   would have stood alone is a kind's score, never the exam's.
derive_route_fault() {
  local case="$1" route="$2" expected picked
  expected="$(jq -r '.route' <<<"$case")"
  if [ -n "$expected" ]; then
    [ "$route" = "$expected" ] || exam_route_fault "$route" "$expected"
    return 0
  fi
  picked="$(jq -r '.picked_recommended' <<<"$case")"
  if [ "$picked" = "$(case_no_words)" ] && [ "$route" = "$EXAM_ALONE" ]; then
    exam_route_alone_fault
  fi
}

# --- A case's result.

# A case's result over its replays, given the case and the replays' results,
# as a JSON array of to_case_result's, in the order run. It passes where
# more than half of them passed (settled 2026-10-07: two of three). Its route
# is the first passing replay's, or the first replay's where none passed;
# its faults and notes are every replay's, each once, so a replay that failed
# shows why even where the case passed. How many replays the stand-in
# settled alone is kept apart from the route: whether a case was a try for
# its kind's score is judged on all of them, never on the one shown.
to_best_of_result() {
  jq -cn --argjson case "$1" --argjson replays "$2" --arg alone "$EXAM_ALONE" '
    def once: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
    ($replays | map(select(.faults | length == 0))) as $passing
    | {name: $case.name, tuning_used: $case.tuning_used,
       route: (($passing[0] // $replays[0] // {}).route // ""),
       runs: ($replays | length), passes: ($passing | length),
       alone: ($replays | map(select(.route == $alone)) | length),
       faults: ($replays | map(.faults) | add // [] | once),
       notes: ($replays | map(.notes) | add // [] | once)}'
}

# One case's result, as JSON {name, tuning_used, route, faults, notes}, given
# the case, the route its replay took (empty where it took none), and its
# faults and notes, one a line. It passed where it holds no fault.
to_case_result() {
  jq -cn --argjson case "$1" --arg route "$2" --arg faults "$3" --arg notes "$4" '{
    name: $case.name, tuning_used: $case.tuning_used, route: $route,
    faults: ($faults | split("\n") | map(select(. != ""))),
    notes: ($notes | split("\n") | map(select(. != "")))}'
}

# The result of a case that cannot be judged, given its file's name and why.
to_unjudged_result() {
  to_case_result "$(jq -cn --arg name "$1" '{name: $name, tuning_used: false}')" "" \
    "$(exam_unjudgeable_fault "$2")" ""
}

# True if the case passed: more than half of its replays passed, where it was
# replayed; no fault, where it is one replay's result.
is_case_passed() {
  jq -e 'if has("runs") then .passes * 2 > .runs else .faults | length == 0 end' >/dev/null <<<"$1"
}

# A case's lines as the exam prints them, given its result and the last
# results, or null where none are kept: whether it passed, failed or dropped,
# how many of its replays passed, then each fault and note under it.
format_case_lines() {
  local result="$1" last="$2" name tuning="" line
  name="$(jq -r '.name' <<<"$result")"
  ! jq -e '.tuning_used' >/dev/null <<<"$result" || tuning="$(exam_tuning_used_words)"
  if is_case_passed "$result"; then
    exam_passed_line "$name" "$tuning" "$(jq -r '.route' <<<"$result")"
  elif [ "$last" = null ]; then
    exam_dropped_unknown_line "$name" "$tuning"
  elif is_case_drop "$name" "$last"; then
    exam_dropped_line "$name" "$tuning"
  else
    exam_failed_new_line "$name" "$tuning"
  fi
  ! jq -e 'has("runs")' >/dev/null <<<"$result" \
    || exam_replays_line "$(jq -r '.passes' <<<"$result")" "$(jq -r '.runs' <<<"$result")"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    exam_detail_line "$line"
  done < <(jq -r '.faults[], .notes[]' <<<"$result")
}
