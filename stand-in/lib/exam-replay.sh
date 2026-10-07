#!/usr/bin/env bash
# The exam's replay of one test case: its reply handed to the stand-in's
# parts as they now stand, in the order the gate runs them, and what each
# answered judged against what the case expects. It asks the models and
# writes nothing. Sourced, never executed.
#
# Not the gate itself: the gate holds a live session's record and answers
# Claude Code, and a replay has neither. So the replay calls the same parts
# the gate calls and the same code the gate routes with, and nothing of its
# own decides where a case goes.
#
# A part that cannot answer fails the case, with its reason, and the parts
# after it are not asked: a case is never passed on what could not be read.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_EXAM_REPLAY:-}" ] || return 0
STAND_IN_LOADED_EXAM_REPLAY=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/reader.sh"
. "$(dirname "${BASH_SOURCE[0]}")/checker.sh"
. "$(dirname "${BASH_SOURCE[0]}")/sorter.sh"
. "$(dirname "${BASH_SOURCE[0]}")/routes.sh"
. "$(dirname "${BASH_SOURCE[0]}")/step-go.sh"
. "$(dirname "${BASH_SOURCE[0]}")/exam.sh"

# What the replay of the case at hand found so far, one line each: its faults
# and its notes, and the route it took, empty until it took one. Set afresh
# for each case by replay_case.
replay_faults=""
replay_notes=""
replay_route=""
# The answer the last part asked gave, set by ask_part.
part_answer=""

add_fault() {
  [ -z "$1" ] || replay_faults+="$1"$'\n'
}

add_note() {
  replay_notes+="$1"$'\n'
}

# The answer of the part named, run as the command given, on stdout; a fault
# naming the part and its reason, and a non-zero status, where it gave none.
# Run in the replay's own shell, never in a command substitution of its
# caller's, so the fault it adds is kept.
ask_part() {
  local part="$1" why answer
  shift
  why="$(mktemp)"
  if ! answer="$("$@" 2>"$why")"; then
    add_fault "$(exam_part_failed_fault "$part" "$(tr '\n' ' ' <"$why" | sed 's/ *$//')")"
    rm -f "$why"
    return 1
  fi
  rm -f "$why"
  part_answer="$answer"
}

# A question's replay, given the case, its reader's form, the preset's
# folder, the rules and conventions entries and the preset's risks. The check
# first: a question breaking an entry goes back to the agent before it is
# sorted, as in the gate. The sorter is still asked where the case names a
# kind, so the kind it gives is judged whatever the check found.
replay_question() {
  local case="$1" form="$2" preset="$3" entries="$4" risks="$5" reply checked sendback sort="" entry route
  reply="$(jq -r '.reply' <<<"$case")"
  ask_part "$(exam_checker_words)" get_checker_answer "$form" "$reply" "$entries" || return 0
  checked="$part_answer"
  add_fault "$(derive_checker_faults "$case" "$checked")"
  sendback="$(derive_checker_sendback "$checked" "$entries")"
  if [ -z "$sendback" ] || [ -n "$(to_case_kind "$case")" ]; then
    ask_part "$(exam_sorter_words)" get_sorter_answer "$form" "$reply" "$preset" || return 0
    sort="$part_answer"
    add_fault "$(derive_kind_fault "$case" "$sort")"
  fi
  if [ -n "$sendback" ]; then
    replay_route="$EXAM_TO_AGENT"
    return 0
  fi
  ask_part "$(exam_preset_words)" get_kind_entry "$preset" "$(jq -r '.kind' <<<"$sort")" || return 0
  entry="$part_answer"
  # A kind with a challenge sends the question back to the agent before any
  # route, as the gate does; what the agent answers it is no part of a case.
  if [ -n "$(jq -r '.challenge' <<<"$entry")" ]; then
    add_note "$(exam_challenged_note "$(jq -r '.name' <<<"$entry")")"
    replay_route="$EXAM_TO_AGENT"
    return 0
  fi
  route="$(jq -r '.route' <<<"$(derive_route "$form" "$sort" "$entry" "$risks" false)")"
  # No case holds the agent's replies to the ladder's rungs yet, so the
  # matcher has nothing to match, and a climb is taken as held, the outcome
  # that would let the answer stand without the operator.
  if [ "$route" = "$ROUTE_LADDER" ] || [ "$route" = "$ROUTE_LIGHT" ]; then
    add_note "$(exam_climb_unreplayed_note "$route")"
  fi
  replay_route="$(to_exam_route "$route")"
}

# A step's report's replay, given the case, its reader's form, the preset's
# folder and the preset's risks: labelled, then weighed for the go, with the
# case's own brief as the one the session held.
replay_step() {
  local case="$1" form="$2" preset="$3" risks="$4" reply sort briefs labels next
  reply="$(jq -r '.reply' <<<"$case")"
  ask_part "$(exam_labeller_words)" get_step_sort "$form" "$reply" "$preset" || return 0
  sort="$part_answer"
  briefs="$(jq -c '.briefs' <<<"$case")"
  labels="$(list_major_labels "$risks")"
  next="$(jq -r '.next' <<<"$(derive_step_go "$form" "$sort" "$briefs" "$labels")")"
  replay_route="$(to_exam_step_route "$next")"
}

# One case's result, as to_case_result gives it, given the case, the name of
# the preset's kind whose route is the step go (empty for none), the preset's
# folder, the rules and conventions entries and the preset's risks.
replay_case() {
  local case="$1" go="$2" preset="$3" entries="$4" risks="$5" step=false form fault
  replay_faults=""
  replay_notes=""
  replay_route=""
  ! is_step_case "$case" "$go" || step=true
  if ask_part "$(exam_reader_words)" get_reader_form "$(jq -r '.reply' <<<"$case")"; then
    form="$part_answer"
    fault="$(derive_reading_fault "$step" "$form")"
    add_fault "$fault"
    if [ -z "$fault" ] && [ "$step" = true ]; then
      replay_step "$case" "$form" "$preset" "$risks"
    elif [ -z "$fault" ]; then
      replay_question "$case" "$form" "$preset" "$entries" "$risks"
    fi
  fi
  [ -z "$replay_route" ] || add_fault "$(derive_route_fault "$case" "$replay_route")"
  to_case_result "$case" "$replay_route" "$replay_faults" "$replay_notes"
}

# One case's result over its replays, as to_best_of_result gives it, given
# what replay_case is handed. The replays run side by side, each in a
# process of its own writing its result to a file, and the case waits for
# all of them (settled 2026-10-07): one after another, every case would cost
# its replays' time over again. Bounded by the number of replays, since the
# cases themselves are run one after another. A replay that ends without a
# result counts as one that failed, with what it said on the way out.
replay_best_of() {
  local case="$1" folder run pids=() replays="" result
  folder="$(mktemp -d)"
  for run in $(seq "$EXAM_REPLAYS"); do
    replay_case "$@" >"$folder/$run" 2>"$folder/$run.why" &
    pids+=("$!")
  done
  for run in "${!pids[@]}"; do
    wait "${pids[$run]}" || true
  done
  for run in $(seq "$EXAM_REPLAYS"); do
    if ! result="$(jq -ce 'select(type == "object")' "$folder/$run" 2>/dev/null)" || [ -z "$result" ]; then
      result="$(to_case_result "$case" "" \
        "$(exam_replay_stopped_fault "$(tr '\n' ' ' <"$folder/$run.why" | sed 's/ *$//')")" "")"
    fi
    replays+="$result"$'\n'
  done
  rm -rf "$folder"
  to_best_of_result "$case" "$(printf '%s' "$replays" | jq -cs .)"
}
