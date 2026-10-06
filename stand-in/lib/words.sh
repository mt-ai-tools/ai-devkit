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

refuse_folder_not_absolute_note() {
  printf 'The stand-in'\''s working folder, %s, is not an absolute path, so the cold second reading cannot be kept out of it.\n' "$1"
}

refuse_reading_empty_note() {
  printf 'The cold second reading came back with no words.\n'
}

refuse_pick_outside_note() {
  printf 'The matcher answered "%s", which is neither an item of the first options, a new choice, nor no longer asking.\n' "$1"
}

refuse_item_outside_note() {
  printf 'The matcher picked "%s", which is not one of the first options as listed.\n' "$1"
}

refuse_item_unasked_note() {
  printf 'The matcher named the item "%s" while saying the reply picks none.\n' "$1"
}

refuse_summary_empty_note() {
  printf 'The summary came back with no words.\n'
}

# The names the refusals above call the forms by.
reader_form_words() { printf "reader's form"; }
sorter_answer_words() { printf "sorter's answer"; }
checker_answer_words() { printf "checker's answer"; }
reading_answer_words() { printf "cold second reading's answer"; }
matcher_answer_words() { printf "matcher's answer"; }
summary_answer_words() { printf "summary's answer"; }

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

refuse_unnamed_message_note() {
  printf '%s, line %s: a quote that does not follow a line opening with its short name in backticks.\n' "$1" "$2"
}

refuse_message_twice_note() {
  printf '%s: the message %s is named twice.\n' "$1" "$2"
}

refuse_ladder_message_missing_note() {
  printf '%s holds no words for the message %s, quoted under its short name.\n' "$1" "$2"
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

refuse_round_twice_note() {
  printf 'The stand-in would have sent the %s round a second time for one question, which it never does.\n' "$1"
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
# for, as the agent retold it plainly, then why it came to them, one line per
# reason; then how it got there; then the cold second reading where one ran.

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
# with the decision asked for and that it did not hold.

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
  printf 'The agent'\''s answers, in order:\n'
}

# The first answer, by its number: the label recommended, and the list it was
# chosen from, its labels already joined into one line.
gate_answer_line() {
  printf '%s. %s, from: %s\n' "$1" "$2" "$3"
}

gate_answer_none_line() {
  printf '%s. No recommendation, from: %s\n' "$1" "$2"
}

# A later answer, by its number, as the matcher picked it against the first
# list: the item it recommends, a new choice, or the question let go.
gate_pick_line() {
  printf '%s. %s\n' "$1" "$2"
}

gate_pick_new_line() {
  printf '%s. A new choice, none of the first options as they stood.\n' "$1"
}

gate_answer_gone_line() {
  printf '%s. The reply no longer asks the question.\n' "$1"
}

# The number of the answer given to the bigger look around.
gate_looked_number() {
  printf '%s (after the bigger look around)' "$1"
}

# How the question got to the operator, as the summary reader tells it.
gate_summary_note() {
  printf 'How it got to you:\n%s\n' "$1"
}

gate_summary_failed_note() {
  printf 'The summary of how it got to you failed, so here are the answers as given. Why:\n%s\n' "$1"
}

# The agent's plain retelling could not be read as a question: the question
# shown is the one first asked, and why, where a part said.
gate_retelling_unread_line() {
  printf -- '- The agent'\''s plain retelling could not be read as a question, so this is the question as first asked.\n'
  [ -z "$1" ] || printf '%s\n' "$1"
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

# --- The question log.

refuse_log_unwritable_note() {
  printf 'The stand-in'\''s question log cannot be written in %s.\n' "$1"
}

refuse_log_busy_note() {
  printf 'The stand-in'\''s question log in %s was held by another session for more than %s seconds.\n' "$1" "$2"
}

refuse_log_unreadable_note() {
  printf 'The stand-in'\''s question log, %s, holds a line that is not a whole question.\n' "$1"
}

# Under the operator's message, where its question could not be logged.
gate_log_failed_line() {
  printf 'This question could not be written to the stand-in'\''s log, so it cannot be counted or reopened. Why:\n%s\n' "$1"
}

# --- The operator's answer. The note goes into the model's context, one line,
# where the answer could not be kept.

refuse_prompt_session_note() {
  printf 'The turn'\''s event carries no session id the stand-in can use.\n'
}

refuse_prompt_text_note() {
  printf 'The turn'\''s event carries no prompt.\n'
}

answer_unrecorded_note() {
  printf 'The stand-in could not keep the user'\''s reply as the answer to its last question, so its log will not show it: %s\n' "$1"
}

# --- The settled list, as the operator reads it.

settled_today_heading() {
  printf 'Stand-in: the questions it settled without you today:\n'
}

settled_all_heading() {
  printf 'Stand-in: every question it settled without you:\n'
}

# One question: its number, and the question as the agent retold it.
settled_item_line() {
  printf '%s. %s\n' "$1" "$2"
}

# Under it: the option settled on, when, and where.
settled_detail_line() {
  printf '   Settled on: %s, at %s, %s.\n' "$1" "$2" "$3"
}

settled_where_session_words() {
  printf 'in session %s' "$1"
}

settled_where_brief_words() {
  printf 'in session %s, working on %s' "$1" "$2"
}

settled_reopen_hint() {
  printf 'Say "reopen" and a number to bring that question back as a normal one.\n'
}

settled_empty_note() {
  printf 'Nothing was settled without you: every kind is still on trial.\n'
}

settled_usage_note() {
  printf 'The stand-in lists the questions it settled today, or every one it ever settled when asked for "all".\n'
}

# --- A reopened question, as the operator reads it.

reopen_heading() {
  printf 'Stand-in: question %s, which it settled without you, is open again.\nIt was settled at %s, %s.\n' "$1" "$2" "$3"
}

reopen_question_line() {
  printf 'The question: %s\n' "$1"
}

reopen_settled_line() {
  printf 'The stand-in settled on: %s\n' "$1"
}

reopen_summary_note() {
  printf 'How it was settled:\n%s\n' "$1"
}

reopen_exchange_hint() {
  printf 'Ask to see the exchange to read every turn word for word.\n'
}

reopen_exchange_heading() {
  printf 'The exchange between the stand-in and the agent, word for word:\n'
}

reopen_agent_turn_heading() {
  printf -- '--- The agent wrote:\n'
}

reopen_stand_in_turn_heading() {
  printf -- '--- The stand-in wrote:\n'
}

reopen_usage_note() {
  printf 'The stand-in reopens a question by the number its settled list shows, as in "reopen 3"; add "exchange" after the number to read every turn word for word.\n'
}

reopen_nothing_note() {
  printf 'There is nothing to reopen: nothing was settled without you, since every kind is still on trial.\n'
}

reopen_unknown_note() {
  printf 'No question the stand-in settled is numbered %s; its settled list shows the numbers there are.\n' "$1"
}

# --- The skill hook's notes to the model, which never sees what the hook
# showed the user, so each says what was shown rather than repeating it.

skill_settled_shown_note() {
  printf 'The stand-in'\''s list of settled questions (%s lines) has been shown to the user above, exactly as printed.\n' "$1"
}

skill_refusal_shown_note() {
  printf 'The stand-in could not do what was asked, and why has been shown to the user above.\n'
}

# The question reopened: number, question as first asked, its options joined,
# and what the stand-in settled on.
reopen_agent_note() {
  printf 'The stand-in'\''s question %s, which it had settled without the user, has been shown to the user above, in full. It is open again: ask the user it now as a normal question in plain conversation, with its options and your recommendation, and wait for their answer. The question as first asked: %s Its options: %s. The stand-in had settled on: %s.\n' "$1" "$2" "$3" "$4"
}

skill_name_unreadable_note() {
  printf 'The stand-in'\''s skill hook cannot read the skill'\''s name from %s.\n' "$1"
}
