#!/usr/bin/env bash
# The exam's run, a thin orchestrator: every test case the project keeps is
# replayed against the stand-in as it now stands, the cases side by side,
# each case's result printed in the cases' order once all are replayed, and
# the exam passes only where no case dropped. A passing exam keeps its
# results for the next to compare with and clears the session's exam owed; a
# failing one keeps both as they were. Sourced, never executed.
#
# A run of its own, the agent's or the operator's, outside the everyday test
# command (decision 7): it asks real models, and the everyday run reaches
# nothing. A case marked as tuned on is replayed like any other and shown so;
# whether it counts toward a kind's score is the score's to say. A passing
# exam prints each kind's score and keeps it with its results, where the end
# report reads which kind to ask the operator about.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_RUN_EXAM:-}" ] || return 0
STAND_IN_LOADED_RUN_EXAM=1
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/runners/side-by-side.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/cases.sh"
. "$(dirname "${BASH_SOURCE[0]}")/owed.sh"
. "$(dirname "${BASH_SOURCE[0]}")/exam.sh"
. "$(dirname "${BASH_SOURCE[0]}")/exam-results.sh"
. "$(dirname "${BASH_SOURCE[0]}")/exam-replay.sh"
. "$(dirname "${BASH_SOURCE[0]}")/score.sh"

# Why a case file cannot be replayed, as its result: unread, or judged one
# that cannot be judged; nothing where it can be replayed.
find_unjudged_result() {
  local file="$1" case problem name
  if ! case="$(read_case "$file" 2>/dev/null)"; then
    to_unjudged_result "$(basename "$file")" "$(exam_case_unreadable_words)"
    return 0
  fi
  problem="$(derive_case_problem "$case")" || return 1
  [ -n "$problem" ] || return 0
  name="$(jq -r '.name' <<<"$case")" || return 1
  to_unjudged_result "$name" "$problem"
}

# Every case file's result, one line each, in the files' order, given the
# files, one path a line, and what every replay is handed.
#
# Every replay of every case runs through the kit's side-by-side runner, as
# one list (settled with the operator 2026-10-07): one after another, the
# exam took 766 s over 27 cases. One list, never a runner per case inside a
# runner over cases, so the runner's bound holds for the whole exam rather
# than for each case: nested, eight cases would run three replays each, and
# every replay is a model call. Each replay writes only its own output, and
# the results are read back in the files' order, so the exam prints and
# judges exactly what it would one at a time. A replay that failed is read
# off its missing result, as get_best_of_result says; the runner refusing to
# run them refuses the exam.
list_case_results() {
  local files="$1" go="$2" preset="$3" entries="$4" risks="$5" folder file unjudged case run items="" status=0
  local place=1 results=() i=0
  folder="$(mktemp -d)" || return 1
  while IFS= read -r file; do
    if ! unjudged="$(find_unjudged_result "$file")"; then
      rm -rf "$folder"
      return 1
    fi
    results+=("$unjudged")
    [ -z "$unjudged" ] || continue
    for run in $(seq "$EXAM_REPLAYS"); do
      items+="$file"$'\n'
    done
  done <<<"$files"
  run_side_by_side "$SIDE_BY_SIDE_JOBS" "$folder" "$(dirname "${BASH_SOURCE[0]}")/exam-replay.sh" \
    replay_case_file "$go" "$preset" "$entries" "$risks" <<<"$items" || status=$?
  if [ "$status" -eq "$SIDE_BY_SIDE_REFUSED" ]; then
    rm -rf "$folder"
    return 1
  fi
  while IFS= read -r file; do
    if [ -z "${results[$i]}" ]; then
      if ! case="$(read_case "$file")" || ! results[i]="$(get_best_of_result "$case" "$folder" "$place")"; then
        rm -rf "$folder"
        return 1
      fi
      place=$((place + EXAM_REPLAYS))
    fi
    printf '%s\n' "${results[$i]}"
    i=$((i + 1))
  done <<<"$files"
  rm -rf "$folder"
}

# Clear the session's exam owed after an exam passed, given the mark as it
# stood when the exam began: only where it still stands unchanged, since one
# rewritten while the exam ran notes an edit the exam may have replayed
# before, which still owes one. Prints what became of it.
clear_owed_mark() {
  local history="$1" session="$2" before="$3" now
  if [ -z "$session" ]; then
    exam_no_session_line
    return 0
  fi
  now="$(find_owed_mark "$history" "$session")" || return 1
  [ -n "$now" ] || return 0
  if [ "$now" != "$before" ]; then
    exam_mark_moved_line
    return 0
  fi
  remove_owed_mark "$history" "$session" || return 1
  exam_mark_cleared_line
}

# Run the exam, given the stand-in's working folder, the session it runs in
# (empty where none is known), the preset's folder and the rules' and
# conventions' folders. Its status is 0 where it passed, and otherwise 1,
# with a refusal on stderr where it could not be run at all: nothing to
# replay, a preset, a collection or the last results that cannot be read, or
# results that cannot be kept.
run_exam() {
  local history="$1" session="$2" preset="$3" rules="$4" conventions="$5"
  local dir files last before="" entries risks go="" file result names="[]" total=0 passed=0 drops=0
  local case name rows="" scores results case_results
  # Its total time is printed last, so a slow exam is seen (settled
  # 2026-10-07): each case asks every part once per replay.
  local started="$SECONDS"
  dir="$(to_cases_dir "$history")"
  files="$(list_case_files "$dir")"
  if [ -z "$files" ]; then
    refuse_exam_no_cases_note "$dir" >&2
    return 1
  fi
  last="$(read_exam_results "$history")" || return 1
  [ -z "$session" ] || before="$(find_owed_mark "$history" "$session")" || return 1
  entries="$(list_check_entries "$rules" "$conventions")" || return 1
  risks="$(list_risks "$preset")" || return 1
  go="$(find_go_kind "$preset")" || return 1
  [ -z "$go" ] || go="$(jq -r '.name' <<<"$go")"
  [ "$last" != null ] || exam_no_results_line
  case_results="$(list_case_results "$files" "$go" "$preset" "$entries" "$risks")" || return 1
  while IFS= read -r file && IFS= read -r result <&3; do
    # Read again for the score: a case that cannot be read was judged
    # unread, and is no try.
    if case="$(read_case "$file" 2>/dev/null)"; then
      rows+="$(to_score_row "$case" "$result")"$'\n'
    fi
    total=$((total + 1))
    name="$(jq -r '.name' <<<"$result")" || return 1
    if is_case_passed "$result"; then
      passed=$((passed + 1))
      names="$(jq -c --arg name "$name" '. + [$name]' <<<"$names")" || return 1
    elif is_case_drop "$name" "$last"; then
      drops=$((drops + 1))
    fi
    format_case_lines "$result" "$last"
  done <<<"$files" 3<<<"$case_results"
  if [ "$drops" -gt 0 ]; then
    exam_failed_note "$total" "$passed" "$((total - passed))" "$drops"
    [ -z "$session" ] || [ -z "$before" ] || exam_mark_kept_line
    exam_time_line "$((SECONDS - started))"
    return 1
  fi
  scores="$(printf '%s' "$rows" | jq -cs .)" || return 1
  scores="$(to_kind_scores "$scores")" || return 1
  results="$(to_exam_results "$names" "$scores")" || return 1
  if ! write_exam_results "$history" "$results"; then
    exam_time_line "$((SECONDS - started))"
    return 1
  fi
  format_score_lines "$scores"
  exam_passed_note "$total" "$passed" "$((total - passed))"
  clear_owed_mark "$history" "$session" "$before" || return 1
  exam_time_line "$((SECONDS - started))"
}
