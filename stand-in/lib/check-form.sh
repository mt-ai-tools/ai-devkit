#!/usr/bin/env bash
# The form check: whether a reader's form, or a sorter's, checker's, reading's,
# matcher's or summary's answer, or the sorter's labelling of a step's report,
# is whole and means one thing, decided in code and never by a model. Every
# function here is a transform. Sourced, never executed.
#
# A form that fails is refused with every reason found, never repaired or
# guessed at: a guessed field is a decision taken by nobody, and a refused
# form is one the gate sends to the operator. The schema a model answers to
# is drawn from the same fields, but Claude Code's check of it is not this
# one's to rely on: what the stand-in decides from is checked here.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"

# The separator between a problem row's parts: the ASCII unit separator, which
# no label a model writes is expected to hold and bash never collapses.
CHECK_US=$'\037'

# What is wrong with a form's shape, against a table of its fields and their
# types: one row per field missing, of the wrong type, or not a field of the
# form at all. A field beyond the table is refused rather than ignored: a
# model that writes one has misread what it was asked for, and nothing it
# then says is worth deciding from.
CHECK_SHAPE='
  . as $form
  | if type != "object" then ["not-object"]
    else
      ($fields | to_entries[] | select(.key as $k | $form | has($k) | not) | ["missing", .key]),
      ($fields | to_entries[]
        | select(.key as $k | $form | has($k))
        | select(($form[.key] | type) != .value)
        | ["wrong-type", .key, .value]),
      ($form | keys_unsorted[] | select(. as $k | $fields | has($k) | not) | ["unknown-field", .])
    end
  | join($us)'

# A list item that is not an object of exactly the fields given, each a string
# with words in it: the one test every form's list of items is held to.
CHECK_ITEM_DEF='
  def bad_item($fields):
    type != "object"
    or ((keys - $fields) != [])
    or (($fields - keys) != [])
    or any(.[]; type != "string" or test("^\\s*$"));'

# What is wrong with a reader's form whose shape is right: what its fields
# say against each other.
#
# A recommendation needs at least two options, whatever else the form says:
# the ladder asks whether the same option is chosen from the same list three
# times, and a list of one has nothing to choose against. A yes-or-no question
# is two options, which the reader's prompt asks it to write out.
#
# A form claiming no question while holding one, or a question with no words,
# contradicts itself; which half is true would be a guess. So does one
# claiming no step ended while saying what the step found, proved or comes
# next.
#
# An option label holding "recommend", in any case, carries the agent's own
# pick, which has its field: the options are what the cold second reading is
# handed, and a label marked "(recommended)" tells it the agent's choice, so
# it reads anchored (found live 2026-10-06). Refused rather than stripped, as
# every broken form is. A real option that happens to hold the word is refused
# too, and goes to the operator: a rare stop they chose over a silent anchor.
#
# A step's words — a problem's state, the proof, where the next step comes
# from, a mark on it — are each one of their own, never the nearest: the step
# go is decided from them, and a word read as the nearest one is a decision
# nobody took.
CHECK_READER_RULES="$CHECK_ITEM_DEF"'
  (select(any(.options[]; type != "string" or test("^\\s*$"))) | ["bad-option"]),
  (.options[] | strings | select(test("recommend"; "i")) | ["marked-option", .]),
  (select(.recommended != "")
    | .recommended as $r
    | select(any(.options[]; . == $r) | not)
    | ["recommended-outside", $r]),
  (select(.recommended != "" and (.options | length) < 2) | ["single-option"]),
  (select(.asks_operator and (.question | test("^\\s*$"))) | ["question-missing"]),
  (select((.asks_operator | not) and (.question != "" or .options != [] or .recommended != ""))
    | ["no-question-but"]),
  (.guidance_answer as $g
    | select(any($guidance[]; . == $g) | not)
    | ["guidance-outside", $g]),
  (.problems[] | select(bad_item($problem_fields)) | ["bad-problem"]),
  (.problems[] | objects | .state | strings | . as $s
    | select(any($states[]; . == $s) | not) | ["state-outside", $s]),
  (.proof as $p | select(any($proofs[]; . == $p) | not) | ["proof-outside", $p]),
  (.next_step_from as $f | select(any($froms[]; . == $f) | not) | ["from-outside", $f]),
  (.next_step_marks[] | tostring as $m | select(any($marks[]; . == $m) | not) | ["mark-outside", $m]),
  (select(.next_step_number < 0 or .next_step_number != (.next_step_number | floor))
    | ["bad-step-number", (.next_step_number | tostring)]),
  (select((.ends_step | not)
      and (.problems != [] or .proof != "" or .next_step != "" or .next_step_number != 0
        or .next_step_from != "" or .next_step_marks != []))
    | ["no-step-but"])
  | join($us)'

# What is wrong with a sorter's answer whose shape is right: a kind or a risk
# the preset does not hold. A name the preset lacks is never matched to the
# nearest one it has.
CHECK_SORTER_RULES='
  (.kind as $k | select(any($kinds[]; . == $k) | not) | ["unknown-kind", $k]),
  (.risks[] | tostring as $r | select(any($risks[]; . == $r) | not) | ["unknown-risk", $r])
  | join($us)'

# What is wrong with the sorter's labelling of a step's report whose shape is
# right: a major problem that is not an object of exactly its fields, or a
# label it was not handed, never matched to the nearest one it was.
CHECK_STEP_SORT_RULES="$CHECK_ITEM_DEF"'
  (.majors[] | select(bad_item($major_fields)) | ["bad-major"]),
  (.majors[] | objects | .label | strings | . as $l
    | select(any($labels[]; . == $l) | not) | ["unknown-label", $l])
  | join($us)'

# What is wrong with a checker's answer whose shape is right: a list item that
# is not an object of exactly its fields, each a string with words in it, and
# a broken entry the checker was not handed. An entry the checker names that
# the project does not hold would send the agent to read something that is
# not there.
CHECK_CHECKER_RULES="$CHECK_ITEM_DEF"'
  (.breaks[] | select(bad_item($break_fields)) | ["bad-break"]),
  (.breaks[] | objects | .entry | strings | . as $e
    | select(any($names[]; . == $e) | not) | ["unknown-entry", $e]),
  (.miscalled[] | select(bad_item($miscalled_fields)) | ["bad-miscalled"])
  | join($us)'

# What is wrong with a cold second reading's answer whose shape is right: a
# reading with no words, which would show the operator a heading over
# nothing.
CHECK_READING_RULES='
  (select(.reading | test("^\\s*$")) | ["reading-empty"])
  | join($us)'

# What is wrong with a matcher's answer whose shape is right: a pick that is
# none of its words, an item that is not one of the first rung's options as
# listed, or an item given with a pick that names none. An item the list does
# not hold is never matched to the nearest one it has: telling a rewording
# from a new choice is the matcher's whole job, and code nearing it would be
# a second, unchecked guess.
CHECK_MATCHER_RULES='
  (.pick as $p | select(any($picks[]; . == $p) | not) | ["pick-outside", $p]),
  (select(.pick == $item_pick)
    | .item as $i
    | select(any($options[]; . == $i) | not)
    | ["item-outside", $i]),
  (select(.pick != $item_pick and .item != "") | ["item-unasked", .item])
  | join($us)'

# What is wrong with a summary's answer whose shape is right: any part with
# no words, which would show the operator a heading over nothing.
CHECK_SUMMARY_RULES='
  (to_entries[] | select(.value | test("^\\s*$")) | ["summary-part-empty", .key])
  | join($us)'

# The input as one compact JSON value; a non-zero status where it is not
# exactly one. Two values one after the other are refused like none: which of
# them is the form would be a guess.
to_one_json_value() {
  local count
  count="$(jq -s 'length' <<<"$1" 2>/dev/null)" || return 1
  [ "$count" = 1 ] || return 1
  jq -c . <<<"$1"
}

# The rows of a form's shape problems, against its table of fields.
derive_shape_problems() {
  jq -r --argjson fields "$2" --arg us "$CHECK_US" "$CHECK_SHAPE" <<<"$1"
}

# Every problem of a reader's form, one row each; nothing for a whole one.
# The rules between fields are read only once the shape is right, since a
# field missing or of the wrong type would make every rule about it misfire.
derive_reader_form_problems() {
  local shape
  shape="$(derive_shape_problems "$1" "$READER_FORM_FIELDS")"
  if [ -n "$shape" ]; then
    printf '%s\n' "$shape"
    return 0
  fi
  jq -r --argjson guidance "$GUIDANCE_ANSWERS" --argjson problem_fields "$PROBLEM_FIELDS" \
    --argjson states "$PROBLEM_STATES" --argjson proofs "$STEP_PROOFS" --argjson froms "$STEP_FROMS" \
    --argjson marks "$STEP_MARKS" --arg us "$CHECK_US" "$CHECK_READER_RULES" <<<"$1"
}

# Every problem of a sorter's answer, one row each, given the kind names and
# the risk names the preset holds as JSON arrays.
derive_sorter_answer_problems() {
  local shape
  shape="$(derive_shape_problems "$1" "$SORTER_ANSWER_FIELDS")"
  if [ -n "$shape" ]; then
    printf '%s\n' "$shape"
    return 0
  fi
  jq -r --argjson kinds "$2" --argjson risks "$3" --arg us "$CHECK_US" \
    "$CHECK_SORTER_RULES" <<<"$1"
}

# Every problem of the sorter's labelling of a step's report, one row each,
# given the label names as a JSON array.
derive_step_sort_problems() {
  local shape
  shape="$(derive_shape_problems "$1" "$STEP_SORT_FIELDS")"
  if [ -n "$shape" ]; then
    printf '%s\n' "$shape"
    return 0
  fi
  jq -r --argjson labels "$2" --argjson major_fields "$MAJOR_FIELDS" --arg us "$CHECK_US" \
    "$CHECK_STEP_SORT_RULES" <<<"$1"
}

# Every problem of a checker's answer, one row each, given the names of the
# entries it was handed as a JSON array.
derive_checker_answer_problems() {
  local shape
  shape="$(derive_shape_problems "$1" "$CHECKER_ANSWER_FIELDS")"
  if [ -n "$shape" ]; then
    printf '%s\n' "$shape"
    return 0
  fi
  jq -r --argjson names "$2" --argjson break_fields "$CHECKER_BREAK_FIELDS" \
    --argjson miscalled_fields "$CHECKER_MISCALLED_FIELDS" --arg us "$CHECK_US" \
    "$CHECK_CHECKER_RULES" <<<"$1"
}

# Every problem of a cold second reading's answer, one row each.
derive_reading_answer_problems() {
  local shape
  shape="$(derive_shape_problems "$1" "$READING_ANSWER_FIELDS")"
  if [ -n "$shape" ]; then
    printf '%s\n' "$shape"
    return 0
  fi
  jq -r --arg us "$CHECK_US" "$CHECK_READING_RULES" <<<"$1"
}

# Every problem of a matcher's answer, one row each, given the first rung's
# option labels as a JSON array.
derive_matcher_answer_problems() {
  local shape
  shape="$(derive_shape_problems "$1" "$MATCHER_ANSWER_FIELDS")"
  if [ -n "$shape" ]; then
    printf '%s\n' "$shape"
    return 0
  fi
  jq -r --argjson picks "$MATCH_PICKS" --arg item_pick "$MATCH_ITEM" --argjson options "$2" \
    --arg us "$CHECK_US" "$CHECK_MATCHER_RULES" <<<"$1"
}

# Every problem of a summary's answer, one row each.
derive_summary_answer_problems() {
  local shape
  shape="$(derive_shape_problems "$1" "$SUMMARY_ANSWER_FIELDS")"
  if [ -n "$shape" ]; then
    printf '%s\n' "$shape"
    return 0
  fi
  jq -r --arg us "$CHECK_US" "$CHECK_SUMMARY_RULES" <<<"$1"
}

# The words for each problem row, the form called by the label given.
to_problem_notes() {
  local label="$1" code arg type
  while IFS="$CHECK_US" read -r code arg type; do
    case "$code" in
      not-object) refuse_not_object_note "$label" ;;
      missing) refuse_missing_field_note "$label" "$arg" ;;
      wrong-type) refuse_wrong_type_note "$label" "$arg" "$type" ;;
      unknown-field) refuse_unknown_field_note "$label" "$arg" ;;
      bad-option) refuse_bad_option_note ;;
      marked-option) refuse_marked_option_note "$arg" ;;
      recommended-outside) refuse_recommended_outside_note "$arg" ;;
      single-option) refuse_single_option_note ;;
      question-missing) refuse_question_missing_note ;;
      no-question-but) refuse_no_question_but_note ;;
      guidance-outside) refuse_guidance_outside_note "$arg" ;;
      unknown-kind) refuse_unknown_kind_note "$arg" ;;
      unknown-risk) refuse_unknown_risk_note "$arg" ;;
      bad-break) refuse_bad_break_note ;;
      unknown-entry) refuse_unknown_entry_note "$arg" ;;
      bad-miscalled) refuse_bad_miscalled_note ;;
      reading-empty) refuse_reading_empty_note ;;
      pick-outside) refuse_pick_outside_note "$arg" ;;
      item-outside) refuse_item_outside_note "$arg" ;;
      item-unasked) refuse_item_unasked_note "$arg" ;;
      summary-part-empty) refuse_summary_part_empty_note "$arg" ;;
      bad-problem) refuse_bad_problem_note ;;
      state-outside) refuse_state_outside_note "$arg" ;;
      proof-outside) refuse_proof_outside_note "$arg" ;;
      from-outside) refuse_from_outside_note "$arg" ;;
      mark-outside) refuse_mark_outside_note "$arg" ;;
      bad-step-number) refuse_bad_step_number_note "$arg" ;;
      no-step-but) refuse_no_step_but_note ;;
      bad-major) refuse_bad_major_note ;;
      unknown-label) refuse_unknown_label_note "$arg" ;;
    esac
  done
}

# The reader's form, compact, where it is whole; every reason it is not on
# stderr and a non-zero status otherwise.
refuse_bad_reader_form() {
  local form problems label
  label="$(reader_form_words)"
  if ! form="$(to_one_json_value "$1")"; then
    refuse_not_json_note "$label" >&2
    return 1
  fi
  problems="$(derive_reader_form_problems "$form")"
  if [ -n "$problems" ]; then
    to_problem_notes "$label" <<<"$problems" >&2
    return 1
  fi
  printf '%s\n' "$form"
}

# The sorter's answer, compact, where it is whole and names only the kinds and
# risks given; every reason it is not on stderr and a non-zero status
# otherwise.
refuse_bad_sorter_answer() {
  local answer problems label
  label="$(sorter_answer_words)"
  if ! answer="$(to_one_json_value "$1")"; then
    refuse_not_json_note "$label" >&2
    return 1
  fi
  problems="$(derive_sorter_answer_problems "$answer" "$2" "$3")"
  if [ -n "$problems" ]; then
    to_problem_notes "$label" <<<"$problems" >&2
    return 1
  fi
  printf '%s\n' "$answer"
}

# The sorter's labelling of a step's report, compact, where it is whole and
# names only the labels given; every reason it is not on stderr and a non-zero
# status otherwise.
refuse_bad_step_sort() {
  local answer problems label
  label="$(step_sort_words)"
  if ! answer="$(to_one_json_value "$1")"; then
    refuse_not_json_note "$label" >&2
    return 1
  fi
  problems="$(derive_step_sort_problems "$answer" "$2")"
  if [ -n "$problems" ]; then
    to_problem_notes "$label" <<<"$problems" >&2
    return 1
  fi
  printf '%s\n' "$answer"
}

# The checker's answer, compact, where it is whole and names only the entries
# given; every reason it is not on stderr and a non-zero status otherwise.
refuse_bad_checker_answer() {
  local answer problems label
  label="$(checker_answer_words)"
  if ! answer="$(to_one_json_value "$1")"; then
    refuse_not_json_note "$label" >&2
    return 1
  fi
  problems="$(derive_checker_answer_problems "$answer" "$2")"
  if [ -n "$problems" ]; then
    to_problem_notes "$label" <<<"$problems" >&2
    return 1
  fi
  printf '%s\n' "$answer"
}

# The cold second reading's answer, compact, where it is whole and holds
# words; every reason it is not on stderr and a non-zero status otherwise.
refuse_bad_reading_answer() {
  local answer problems label
  label="$(reading_answer_words)"
  if ! answer="$(to_one_json_value "$1")"; then
    refuse_not_json_note "$label" >&2
    return 1
  fi
  problems="$(derive_reading_answer_problems "$answer")"
  if [ -n "$problems" ]; then
    to_problem_notes "$label" <<<"$problems" >&2
    return 1
  fi
  printf '%s\n' "$answer"
}

# The matcher's answer, compact, where it is whole and names only an item of
# the options given; every reason it is not on stderr and a non-zero status
# otherwise.
refuse_bad_matcher_answer() {
  local answer problems label
  label="$(matcher_answer_words)"
  if ! answer="$(to_one_json_value "$1")"; then
    refuse_not_json_note "$label" >&2
    return 1
  fi
  problems="$(derive_matcher_answer_problems "$answer" "$2")"
  if [ -n "$problems" ]; then
    to_problem_notes "$label" <<<"$problems" >&2
    return 1
  fi
  printf '%s\n' "$answer"
}

# The summary's answer, compact, where it is whole and every part holds
# words; every reason it is not on stderr and a non-zero status otherwise.
refuse_bad_summary_answer() {
  local answer problems label
  label="$(summary_answer_words)"
  if ! answer="$(to_one_json_value "$1")"; then
    refuse_not_json_note "$label" >&2
    return 1
  fi
  problems="$(derive_summary_answer_problems "$answer")"
  if [ -n "$problems" ]; then
    to_problem_notes "$label" <<<"$problems" >&2
    return 1
  fi
  printf '%s\n' "$answer"
}

# The reader's form, checked again and holding a question; a refusal on
# stderr and a non-zero status otherwise. Checked again rather than trusted
# from whoever handed it in: the sorter and the checker are only ever asked
# about a form the check passed, and only about a question, since a reply that
# asks nothing has no kind to be and no option to break anything.
refuse_questionless_form() {
  local form
  form="$(refuse_bad_reader_form "$1")" || return 1
  if ! jq -e '.asks_operator' >/dev/null <<<"$form"; then
    refuse_no_question_note >&2
    return 1
  fi
  printf '%s\n' "$form"
}

# The reader's form, checked again and reporting a step ended; a refusal on
# stderr and a non-zero status otherwise. Checked again for the reason a
# question's form is: the sorter only ever labels a report the check passed.
refuse_stepless_form() {
  local form
  form="$(refuse_bad_reader_form "$1")" || return 1
  if ! jq -e '.ends_step' >/dev/null <<<"$form"; then
    refuse_no_step_note >&2
    return 1
  fi
  printf '%s\n' "$form"
}
