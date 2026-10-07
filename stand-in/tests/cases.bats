bats_require_minimum_version 1.5.0

# Behavior tests for the test cases: which log lines become cases, what a
# case file says, what it is called, and how a case already written is found
# and a taken name avoided. Pure but for the folder of cases, so no model is
# asked here.

load fake-claude
load question-log

setup() {
  setup_fake_claude
  . "$lib/cases.sh"
  dir="$BATS_TEST_TMPDIR/answers"
}

# A log line given as log_line makes it, answered as given, under the brief.
answered_line() {
  jq -c --arg answer "$3" '.answer = $answer' <<<"$(log_line "$1" "$2" session-1 2026-10-06T21:58:10Z five '["stand-in-loops"]')"
}

# A whole case-writer's form, the operator picking the recommended option.
case_form() {
  jq -c "${1:-.}" <<<'{"answers":true,"title":"How many retries","summary":"How many times a failing call is tried.","reply":"A call fails now and then.\nShould it be tried five times or ten? I recommend five.","options":["Five tries","Ten tries"],"recommended":"Five tries","answered":"Five tries.","picked":"Five tries","security_gap":false,"why":"Ten holds the page too long."}'
}

@test "the brief's answered questions that reached the operator become cases, and nothing else, the trial's own question included" {
  lines="$(printf '%s\n' \
    "$(answered_line 1 "$OUTCOME_TO_OPERATOR" a)" \
    "$(answered_line 2 "$OUTCOME_WOULD_HAVE_APPROVED" go)" \
    "$(answered_line 3 "$OUTCOME_TO_OPERATOR" "")" \
    "$(answered_line 4 "$OUTCOME_SETTLED" "")" \
    "$(answered_line 5 "$OUTCOME_DROPPED" "")" \
    "$(jq -c '.round = []' <<<"$(answered_line 6 "$OUTCOME_TO_OPERATOR" go)")" \
    "$(jq -c '.closing = {number: 1}' <<<"$(answered_line 7 "$OUTCOME_TO_OPERATOR" ok)")" \
    "$(jq -c '.briefs = ["other"]' <<<"$(answered_line 8 "$OUTCOME_TO_OPERATOR" a)")" \
    "$(jq -c '.briefs = null' <<<"$(answered_line 9 "$OUTCOME_TO_OPERATOR" a)")" \
    "$(jq -c '.trust = {kind: "defaults"}' <<<"$(answered_line 10 "$OUTCOME_TO_OPERATOR" yes)")")"
  run to_case_lines "$lines" '["stand-in-loops"]'
  [ "$status" -eq 0 ]
  [ "$(jq -s -c 'map(.number)' <<<"$output")" = "[1,2]" ]
  run to_case_lines "" '["stand-in-loops"]'
  [ -z "$output" ]
}

@test "a case file holds the form's words and the log's facts, its header one line a field" {
  line="$(answered_line 3 "$OUTCOME_WOULD_HAVE_APPROVED" "a")"
  run to_case_text "$line" "$(case_form)"
  [ "$status" -eq 0 ]
  expected='---
summary: How many times a failing call is tried.
date: 2026-10-06
brief: stand-in-loops
kind: defaults
alone: yes
picked-recommended: yes
security-gap: no
tuning: none
log-id: id-3
---

# How many retries

## Reply

=====REPLY START=====
A call fails now and then.
Should it be tried five times or ten? I recommend five.
=====REPLY END=====

## The operator'"'"'s answer

Five tries.

## Why

Ten holds the page too long.'
  [ "$output" = "$expected" ]
  # Nothing of the log's own words: the exchange as typed stays out.
  [[ "$output" != *"Five or ten? I recommend five. (3)"* ]]
}

@test "a case brought to the operator, picked against the recommendation, with no kind or why, says so" {
  line="$(jq -c '.kind = null | .briefs = ["a", "b\nc"]' <<<"$(answered_line 4 "$OUTCOME_TO_OPERATOR" "ten")")"
  run to_case_text "$line" "$(case_form '.picked = "Ten tries" | .why = ""')"
  [ "$status" -eq 0 ]
  [ "$(sed -n '4,7p' <<<"$output")" = $'brief: a, b c\nkind: unknown\nalone: no\npicked-recommended: no' ]
  [ "$(tail -n 1 <<<"$output")" = "$(case_no_why_words)" ]
  run to_case_text "$line" "$(case_form '.picked = "" | .recommended = ""')"
  [ "$(sed -n '7p' <<<"$output")" = "picked-recommended: no" ]
  # Turned down for a security gap, as the case-writer read the answer.
  run to_case_text "$line" "$(case_form '.picked = "Ten tries" | .security_gap = true')"
  [ "$(sed -n '7,8p' <<<"$output")" = $'picked-recommended: no\nsecurity-gap: yes' ]
}

@test "a case is named by its date and title in plain words, cut at a word" {
  [ "$(to_case_slug "How many retries?")" = "how-many-retries" ]
  [ "$(to_case_slug "  Ünïcode & spaces -- here ")" = "n-code-spaces-here" ]
  [ "$(to_case_slug "?!")" = "$CASE_SLUG_FALLBACK" ]
  long="$(to_case_slug "$(printf 'word%.0s ' {1..30})")"
  [ "${#long}" -le "$CASE_SLUG_LENGTH" ]
  [[ "$long" != *- ]]
  [ "$(to_case_date "$(answered_line 3 "$OUTCOME_TO_OPERATOR" a)")" = 2026-10-06 ]
}

@test "a case already written from a line is found by the id in its header, wherever it is named" {
  run find_case_path "$dir" id-3
  [ -z "$output" ]
  write_case_file "$dir/renamed.md" "$(to_case_text "$(answered_line 3 "$OUTCOME_TO_OPERATOR" a)" "$(case_form)")"
  write_case_file "$dir/other.md" "$(to_case_text "$(answered_line 4 "$OUTCOME_TO_OPERATOR" a)" "$(case_form)")"
  run find_case_path "$dir" id-3
  [ "$output" = "$dir/renamed.md" ]
  run find_case_path "$dir" id-9
  [ -z "$output" ]
}

@test "a taken name gets the line's id after it, and an id that could leave the folder is refused" {
  run find_free_case_path "$dir" 2026-10-06 retries id-3
  [ "$output" = "$dir/2026-10-06-retries.md" ]
  write_case_file "$dir/2026-10-06-retries.md" "taken"
  run find_free_case_path "$dir" 2026-10-06 retries id-3
  [ "$output" = "$dir/2026-10-06-retries-id-3.md" ]
  write_case_file "$dir/2026-10-06-retries-id-3.md" "taken"
  run --separate-stderr find_free_case_path "$dir" 2026-10-06 retries id-3
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_cases_unwritable_note "$dir")" ]
  run --separate-stderr find_free_case_path "$dir" 2026-10-06 retries "../x"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_case_bad_id_note "../x")" ]
}

@test "a case is written whole, and one that cannot be is refused, leaving no draft" {
  write_case_file "$dir/a.md" $'line one\nline two'
  [ "$(cat "$dir/a.md")" = $'line one\nline two' ]
  mkdir -p "$BATS_TEST_TMPDIR/locked"
  chmod a-w "$BATS_TEST_TMPDIR/locked"
  run --separate-stderr write_case_file "$BATS_TEST_TMPDIR/locked/a.md" "text"
  chmod u+w "$BATS_TEST_TMPDIR/locked"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_cases_unwritable_note "$BATS_TEST_TMPDIR/locked")" ]
  [ -z "$(ls -A "$BATS_TEST_TMPDIR/locked")" ]
}
