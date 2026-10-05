#!/usr/bin/env bash
# Every word the stand-in hands whoever runs it — why a model's answer or a
# form was refused, why the preset could not be read — in one place, so the
# suite asserts the wiring rather than the wording. Sourced, never executed.
#
# A refusal here is a reason the gate marks a question with when it sends it
# to the operator, so each says what was wrong in words a person reads cold.

# --- Asking a model.

refuse_model_timeout_note() {
  printf 'The %s model gave no answer within %s seconds.\n' "$1" "$2"
}

refuse_model_exit_note() {
  printf 'Claude Code, asking the %s model, stopped with status %s.\n' "$1" "$2"
}

refuse_model_unreadable_note() {
  printf 'The %s model'\''s answer could not be read as the form it was asked for.\n' "$1"
}

refuse_model_error_note() {
  printf 'Claude Code, asking the %s model, answered with an error.\n' "$1"
}

# --- The reader's form and the sorter's answer. Each names the field, so the
# operator sees which part of the reading broke.

refuse_not_json_note() {
  printf 'The %s is not one JSON value.\n' "$1"
}

refuse_not_object_note() {
  printf 'The %s is not a JSON object.\n' "$1"
}

refuse_missing_field_note() {
  printf 'The %s has no %s.\n' "$1" "$2"
}

refuse_wrong_type_note() {
  printf 'The %s'\''s %s is not a %s.\n' "$1" "$2" "$3"
}

refuse_unknown_field_note() {
  printf 'The %s holds %s, which is no field of it.\n' "$1" "$2"
}

refuse_bad_option_note() {
  printf 'The reader'\''s form holds an option that is not a short label.\n'
}

refuse_recommended_outside_note() {
  printf 'The reader'\''s form recommends "%s", which is not among its options.\n' "$1"
}

refuse_single_option_note() {
  printf 'The reader'\''s form recommends an option from fewer than two; a recommendation needs something to be chosen over.\n'
}

refuse_question_missing_note() {
  printf 'The reader'\''s form says the reply asks the operator, but holds no question.\n'
}

refuse_no_question_but_note() {
  printf 'The reader'\''s form says the reply asks the operator nothing, yet holds a question, options or a recommendation.\n'
}

refuse_guidance_outside_note() {
  printf 'The reader'\''s form answers the guidance challenge with "%s", which is not one of its words.\n' "$1"
}

refuse_unknown_kind_note() {
  printf 'The sorter named the kind "%s", which the preset does not hold.\n' "$1"
}

refuse_unknown_risk_note() {
  printf 'The sorter named the risk "%s", which the preset does not hold.\n' "$1"
}

refuse_nothing_to_sort_note() {
  printf 'The reader'\''s form holds no question to the operator, so there is nothing to sort.\n'
}

# The names the refusals above call the two forms by.
reader_form_words() { printf "reader's form"; }
sorter_answer_words() { printf "sorter's answer"; }

# --- The preset.

refuse_no_kinds_note() {
  printf 'The stand-in preset holds no kinds of question in %s.\n' "$1"
}

refuse_kind_summary_note() {
  printf 'The kind of question %s has no summary.\n' "$1"
}

refuse_no_risks_note() {
  printf 'The stand-in preset holds no named risk in %s.\n' "$1"
}

refuse_unnamed_risk_note() {
  printf '%s, line %s: a risk that does not open with its short name in backticks.\n' "$1" "$2"
}

refuse_risk_twice_note() {
  printf '%s: the risk %s is named twice.\n' "$1" "$2"
}

refuse_unreadable_file_note() {
  printf '%s cannot be read.\n' "$1"
}

refuse_unknown_placeholder_note() {
  printf 'The prompt %s holds a placeholder the stand-in does not fill.\n' "$1"
}

# --- The entry.

refuse_usage_note() {
  printf 'Usage: read-reply (the reply on stdin) | sort <reader form> (the reply on stdin)\n'
}
