#!/usr/bin/env bash
# The exam's last results: which cases passed the last exam that passed, and
# the trial's score per kind it found, kept in the stand-in's own working
# folder, on this machine alone. What a drop is is read against them, and
# which kind the end report asks about. Sourced, never executed.
#
# A drop is a case that passed the last passing exam and fails now: only a
# drop blocks a change (settled 2026-10-01/02, decision 7). A case that never
# passed is reported but does not block: a case the stand-in has always got
# wrong says nothing about the change at hand, and blocking on it would hold
# every change behind work nobody asked for. Where no last results are kept —
# never written on this machine, or lost — whether a failing case passed
# before cannot be told, so every failing case counts as a drop: a change is
# never let through on a comparison that could not be made. Results that
# cannot be read are refused rather than taken as none, for the same reason.
#
# Kept per machine, beside the switches and the log, rather than committed
# with the cases: each machine's exams run against its own checkout, and a
# result committed from one would be another machine's word for this one.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_EXAM_RESULTS:-}" ] || return 0
STAND_IN_LOADED_EXAM_RESULTS=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The results' folder inside the stand-in's working folder, and its one file.
EXAM_SUBFOLDER="exam"
EXAM_RESULTS_NAME="last-passed.json"

# What the results must be to be read: the names of the case files that
# passed, and the trial's score per kind, as score.sh makes it. A case is
# known by its file's name, the one thing every case has, the seed cases
# included, which carry no log line's id. Results kept before the score was
# may lack it, and are read as holding no score: no kind is then asked about
# until a passing exam keeps one.
EXAM_RESULTS_SHAPE='
  type == "object"
  and (.passed | type == "array" and all(.[]; type == "string"))
  and ((has("scores") | not) or (.scores | type == "object"))'

# --- Transforms.

# The results' file, from the stand-in's working folder.
to_exam_results_path() {
  printf '%s/%s/%s\n' "$1" "$EXAM_SUBFOLDER" "$EXAM_RESULTS_NAME"
}

# The results to keep, given the names of the cases that passed, as a JSON
# array, and every kind's score, as one JSON object. The score is kept with
# the results of a passing exam alone: a stand-in that dropped a case is not
# one whose score should ask the operator for trust.
to_exam_results() {
  jq -cn --argjson passed "$1" --argjson scores "$2" '{passed: ($passed | unique), scores: $scores}'
}

# True if a failing case of the name given is a drop, given the last results,
# or null where none are kept.
is_case_drop() {
  jq -en --arg name "$1" --argjson last "$2" '$last == null or any($last.passed[]; . == $name)' >/dev/null
}

# --- Reads.

# The last results, compact; null where none are kept. Results that cannot be
# read are refused on stderr with a non-zero status.
read_exam_results() {
  local file results
  file="$(to_exam_results_path "$1")"
  if [ ! -e "$file" ]; then
    printf 'null\n'
    return 0
  fi
  if ! results="$(jq -ce "select($EXAM_RESULTS_SHAPE)" "$file" 2>/dev/null)" || [ -z "$results" ]; then
    refuse_exam_results_unreadable_note "$file" >&2
    return 1
  fi
  printf '%s\n' "$results"
}

# --- Writes.

# Keep a passing exam's results, through a hidden draft moved over the last,
# so no exam reads half of them. Results that cannot be kept are refused on
# stderr with a non-zero status.
write_exam_results() {
  local file dir draft
  file="$(to_exam_results_path "$1")"
  dir="$(dirname "$file")"
  draft="$dir/.$(basename "$file").$$"
  if ! mkdir -p "$dir" 2>/dev/null || ! { printf '%s\n' "$2" >"$draft"; } 2>/dev/null \
    || ! mv -f "$draft" "$file" 2>/dev/null; then
    rm -f "$draft" 2>/dev/null || true
    refuse_exam_results_unwritable_note "$dir" >&2
    return 1
  fi
}
