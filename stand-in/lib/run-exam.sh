#!/usr/bin/env bash
# The exam's run, a thin orchestrator: every test case the project keeps is
# replayed against the stand-in as it now stands, each case's result printed
# as it comes, and the exam passes only where no case dropped. A passing exam
# keeps its results for the next to compare with and clears the session's
# exam owed; a failing one keeps both as they were. Sourced, never executed.
#
# A run of its own, the agent's or the operator's, outside the everyday test
# command (decision 7): it asks real models, and the everyday run reaches
# nothing. A case marked as tuned on is replayed like any other and shown so;
# whether it counts toward a kind's score is the score's to say.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_RUN_EXAM:-}" ] || return 0
STAND_IN_LOADED_RUN_EXAM=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/cases.sh"
. "$(dirname "${BASH_SOURCE[0]}")/owed.sh"
. "$(dirname "${BASH_SOURCE[0]}")/exam.sh"
. "$(dirname "${BASH_SOURCE[0]}")/exam-results.sh"
. "$(dirname "${BASH_SOURCE[0]}")/exam-replay.sh"

# One case file's result: read, judged whether it can be judged, and
# replayed; given its path and what every replay is handed.
examine_case() {
  local file="$1" go="$2" preset="$3" entries="$4" risks="$5" case problem
  if ! case="$(read_case "$file" 2>/dev/null)"; then
    to_unjudged_result "$(basename "$file")" "$(exam_case_unreadable_words)"
    return 0
  fi
  problem="$(derive_case_problem "$case")"
  if [ -n "$problem" ]; then
    to_unjudged_result "$(jq -r '.name' <<<"$case")" "$problem"
    return 0
  fi
  replay_best_of "$case" "$go" "$preset" "$entries" "$risks"
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
  while IFS= read -r file; do
    result="$(examine_case "$file" "$go" "$preset" "$entries" "$risks")"
    total=$((total + 1))
    if is_case_passed "$result"; then
      passed=$((passed + 1))
      names="$(jq -c --arg name "$(jq -r '.name' <<<"$result")" '. + [$name]' <<<"$names")"
    elif is_case_drop "$(jq -r '.name' <<<"$result")" "$last"; then
      drops=$((drops + 1))
    fi
    format_case_lines "$result" "$last"
  done <<<"$files"
  if [ "$drops" -gt 0 ]; then
    exam_failed_note "$total" "$passed" "$((total - passed))" "$drops"
    [ -z "$session" ] || [ -z "$before" ] || exam_mark_kept_line
    exam_time_line "$((SECONDS - started))"
    return 1
  fi
  if ! write_exam_results "$history" "$(to_exam_results "$names")"; then
    exam_time_line "$((SECONDS - started))"
    return 1
  fi
  exam_passed_note "$total" "$passed" "$((total - passed))"
  clear_owed_mark "$history" "$session" "$before" || return 1
  exam_time_line "$((SECONDS - started))"
}
