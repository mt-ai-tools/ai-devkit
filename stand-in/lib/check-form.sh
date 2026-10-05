#!/usr/bin/env bash
# The form check: whether a reader's form or a sorter's answer is whole and
# means one thing, decided in code and never by a model. Every function here
# is a transform. Sourced, never executed.
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

# What is wrong with a reader's form whose shape is right: what its fields
# say against each other.
#
# A recommendation needs at least two options, whatever else the form says:
# the ladder asks whether the same option is chosen from the same list three
# times, and a list of one has nothing to choose against. A yes-or-no question
# is two options, which the reader's prompt asks it to write out.
#
# A form claiming no question while holding one, or a question with no words,
# contradicts itself; which half is true would be a guess.
CHECK_READER_RULES='
  (select(any(.options[]; type != "string" or test("^\\s*$"))) | ["bad-option"]),
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
    | ["guidance-outside", $g])
  | join($us)'

# What is wrong with a sorter's answer whose shape is right: a kind or a risk
# the preset does not hold. A name the preset lacks is never matched to the
# nearest one it has.
CHECK_SORTER_RULES='
  (.kind as $k | select(any($kinds[]; . == $k) | not) | ["unknown-kind", $k]),
  (.risks[] | tostring as $r | select(any($risks[]; . == $r) | not) | ["unknown-risk", $r])
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
  jq -r --argjson guidance "$GUIDANCE_ANSWERS" --arg us "$CHECK_US" \
    "$CHECK_READER_RULES" <<<"$1"
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
      recommended-outside) refuse_recommended_outside_note "$arg" ;;
      single-option) refuse_single_option_note ;;
      question-missing) refuse_question_missing_note ;;
      no-question-but) refuse_no_question_but_note ;;
      guidance-outside) refuse_guidance_outside_note "$arg" ;;
      unknown-kind) refuse_unknown_kind_note "$arg" ;;
      unknown-risk) refuse_unknown_risk_note "$arg" ;;
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
