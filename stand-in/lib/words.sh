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

refuse_no_question_note() {
  printf 'The reader'\''s form holds no question to the operator, so there is nothing to sort or check.\n'
}

refuse_bad_break_note() {
  printf 'The checker'\''s answer holds a broken entry that is not an entry'\''s file name and why it is broken.\n'
}

refuse_unknown_entry_note() {
  printf 'The checker named the entry "%s", which is no rule or convention it was handed.\n' "$1"
}

refuse_bad_miscalled_note() {
  printf 'The checker'\''s answer holds a miscalled item that is not what it was called and what it is.\n'
}

refuse_reading_empty_note() {
  printf 'The cold second reading came back with no words.\n'
}

# The names the refusals above call the three forms by.
reader_form_words() { printf "reader's form"; }
sorter_answer_words() { printf "sorter's answer"; }
checker_answer_words() { printf "checker's answer"; }
reading_answer_words() { printf "cold second reading's answer"; }

# --- The rules and conventions.

refuse_no_rules_note() {
  printf 'No rule files at %s, so no question can be checked against the rules.\n' "$1"
}

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

refuse_kind_route_note() {
  printf 'The kind of question %s has the route "%s", which is neither %s nor %s.\n' "$1" "$2" "$3" "$4"
}

refuse_second_challenge_alone_note() {
  printf 'The kind of question %s has a second challenge but no first.\n' "$1"
}

refuse_ladder_challenges_note() {
  printf '%s: the ladder needs %s challenges, each the quote under its rung; it holds %s.\n' "$1" "$2" "$3"
}

refuse_unknown_placeholder_note() {
  printf 'The prompt %s holds a placeholder the stand-in does not fill.\n' "$1"
}

# --- The entry.

refuse_usage_note() {
  printf 'Usage: read-reply (the reply on stdin) | sort <reader form> (the reply on stdin)\n'
}

# --- The gate's event, switch and state.

refuse_event_unreadable_note() {
  printf 'The end-of-reply event is not a JSON object.\n'
}

refuse_event_session_note() {
  printf 'The end-of-reply event carries no session id the stand-in can use.\n'
}

refuse_event_reply_note() {
  printf 'The end-of-reply event carries no reply text.\n'
}

refuse_switch_unknown_note() {
  printf 'The stand-in'\''s switch folder %s cannot be searched, so whether the stand-in is on for this session cannot be told.\n' "$1"
}

refuse_state_unreadable_note() {
  printf 'The stand-in'\''s record of this session, %s, cannot be read.\n' "$1"
}

refuse_state_unwritable_note() {
  printf 'The stand-in'\''s record of this session cannot be written in %s.\n' "$1"
}

# --- What the gate sends back to the agent. Every message to an agent opens
# with the same words, so the agent, and the operator reading along, tell the
# stand-in apart from the operator and from Claude Code's own labels.

gate_from_note() {
  printf 'From the stand-in: %s\n' "$1"
}

gate_no_recommendation_note() {
  gate_from_note 'state one recommendation among your options.'
}

gate_challenge_note() {
  gate_from_note "$1"
}

gate_checker_sendback_note() {
  gate_from_note 'your question goes against what the project has written down.'
  printf '%s' "$1"
  printf 'Read them and ask again.\n'
}

# One broken entry: what it is, its file name, where it lies, and why.
gate_breaks_line() {
  printf -- '- It breaks the %s %s (%s): %s\n' "$1" "$2" "$3" "$4"
}

# What one entry of each collection is called.
rule_words() { printf 'rule'; }
convention_words() { printf 'convention'; }

# What the checker says the thing really is stands as it wrote it, after the
# sentence rather than inside it: it is a model's own sentence, capitals and
# full stop included.
gate_miscalled_line() {
  printf -- '- What you called "%s" is no rule or convention of the project. What it is: %s\n' "$1" "$2"
}

gate_explains_code_line() {
  printf -- '- The sentence you propose explains how some code works: a convention says what must stay true; how the code does it is a comment beside that code.\n'
}

# --- What the gate brings the operator. It opens with the decision asked
# for, then why it came to them, one line per reason.

gate_operator_note() {
  printf 'Stand-in: a question for you: %s\nWhy it came to you:\n%s' "$1" "$2"
}

gate_kind_line() {
  printf -- '- It is a question of the kind %s (%s), which always comes to you.\n' "$1" "$2"
}

gate_risk_line() {
  printf -- '- The recommended option, %s, carries the risk %s: %s\n' "$1" "$2" "$3"
}

gate_unsure_line() {
  printf -- '- The stand-in could not tell for certain what kind of question it is; its best reading was %s.\n' "$1"
}

gate_kept_line() {
  printf -- '- The agent kept its proposal through the stand-in'\''s challenge; its reasons are in its reply.\n'
}

gate_unanswered_line() {
  printf -- '- The stand-in challenged the proposal ("%s"), and the reply neither drops it nor keeps it.\n' "$1"
}

gate_loop_line() {
  printf -- '- The stand-in has sent it back to the agent %s times in a row, and hands it to you rather than hold the reply again. It would have sent back:\n%s' "$1" "$2"
}

# --- What the ladder brings the operator. A held answer opens with the
# decision asked for and what the stand-in would have approved; a changed one
# with the decision asked for, then every answer in order, then the cold
# second reading or why there is none.

gate_held_note() {
  printf 'Stand-in: a question for you: %s\nThe stand-in would have approved: %s (held %s times).\nWhy it came to you:\n%s' "$1" "$2" "$3" "$4"
}

gate_trial_line() {
  printf -- '- Its kind, %s, is still on trial: until you switch it, every answer the stand-in would approve still comes to you.\n' "$1"
}

gate_moved_line() {
  printf -- '- The agent'\''s answer did not hold under the stand-in'\''s challenges.\n'
}

gate_answers_heading() {
  printf 'Its %s answers, in order:\n' "$1"
}

# One rung's answer, by its number: the label recommended, and the list it
# was chosen from, its labels already joined into one line.
gate_answer_line() {
  printf '%s. %s, from: %s\n' "$1" "$2" "$3"
}

gate_answer_none_line() {
  printf '%s. No recommendation, from: %s\n' "$1" "$2"
}

gate_answer_gone_line() {
  printf '%s. The reply no longer asks the question.\n' "$1"
}

# The reading stands as the model wrote it, under a line saying what it is:
# another model's view, never a decision.
gate_reading_note() {
  printf 'A cold second reading by another model, which decides nothing:\n%s\n' "$1"
}

gate_reading_failed_line() {
  printf 'The cold second reading failed, so there is none. Why:\n%s\n' "$1"
}

# A gate that could not judge a reply: the reasons, one per line, as the part
# that failed gave them.
gate_broken_note() {
  local why="$1"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'Stand-in: this reply was not judged, so it is yours to read.\nWhy:\n%s\n' "$why"
}
