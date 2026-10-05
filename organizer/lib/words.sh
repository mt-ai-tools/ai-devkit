#!/usr/bin/env bash
# Every word the organizer hands the operator — problems, refusals, the list's
# headings and ages — in one place, so the suite asserts the wiring rather than
# the wording. Sourced, never executed.

# --- Problems the check finds. Each names the brief first, so a list of them
# reads as which brief to open and what to fix in it.

problem_bad_name_note() {
  printf '%s: the file name is not a brief name (lower-case letters, digits and hyphens).\n' "$1"
}

problem_missing_field_note() {
  printf '%s: the header has no %s.\n' "$1" "$2"
}

problem_folded_summary_note() {
  printf '%s: the summary is not written on its own line.\n' "$1"
}

problem_not_a_list_note() {
  printf '%s: %s is not a list in [...] form.\n' "$1" "$2"
}

problem_bad_after_name_note() {
  printf '%s: after holds "%s", which is not a brief name.\n' "$1" "$2"
}

problem_after_missing_note() {
  printf '%s: after names %s, which is no brief in the folder.\n' "$1" "$2"
}

problem_cycle_note() {
  printf '%s: its after list leads back to itself.\n' "$1"
}

problem_path_outside_note() {
  printf '%s: %s holds %s, which leaves the project root.\n' "$1" "$2" "$3"
}

problem_touches_missing_note() {
  printf '%s: touches %s, which does not exist.\n' "$1" "$2"
}

problem_creates_folder_missing_note() {
  printf '%s: creates %s, whose folder does not exist.\n' "$1" "$2"
}

problem_mark_orphan_note() {
  printf 'taken mark %s: names no brief in the folder.\n' "$1"
}

problem_mark_unreadable_note() {
  printf 'taken mark %s: not a session and a since line.\n' "$1"
}

# --- Refusals: the operation stops and changes nothing.

refuse_usage_note() {
  printf 'Usage: list | check | take <brief> <session> | free <session> | free-brief <brief> | done <brief>\n'
}

refuse_bad_name_note() {
  printf '"%s" is not a brief name (lower-case letters, digits and hyphens).\n' "$1"
}

refuse_bad_session_note() {
  printf '"%s" is not a session id (letters, digits and hyphens).\n' "$1"
}

refuse_no_brief_note() {
  printf 'There is no brief named %s.\n' "$1"
}

refuse_no_briefs_folder_note() {
  printf 'There is no briefs folder at %s.\n' "$1"
}

refuse_taken_note() {
  printf '%s is taken by session %s since %s.\n' "$1" "$2" "$3"
}

refuse_mark_unreadable_note() {
  printf 'The taken mark for %s cannot be read; free it before taking the brief.\n' "$1"
}

refuse_header_unreadable_note() {
  printf '%s: its after list cannot be read, so no brief was changed.\n' "$1"
}

# --- The list.

list_problems_heading() { printf 'Problems:\n'; }
list_ready_heading() { printf 'Ready now:\n'; }
list_waiting_heading() { printf 'Waiting:\n'; }
list_taken_heading() { printf 'Taken:\n'; }

list_ready_line() {
  printf -- '- %s — %s\n' "$1" "$2"
}

list_same_place_ready_line() {
  printf '  same place as ready %s\n' "$1"
}

list_same_place_taken_line() {
  printf '  same place as taken %s (%s)\n' "$1" "$2"
}

list_waiting_line() {
  printf -- '- %s — waits on: %s\n' "$1" "$2"
}

list_taken_line() {
  printf -- '- %s — taken %s ago (session %s)\n' "$1" "$2" "$3"
}

list_problem_line() {
  printf -- '- %s\n' "$1"
}

# --- Ages, by the unit format_age picked.

age_minutes_words() { printf '%s min' "$1"; }
age_hours_words() { printf '%s h' "$1"; }
age_days_words() { printf '%s d' "$1"; }
