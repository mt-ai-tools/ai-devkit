#!/usr/bin/env bash
# Every word the stand-in hands whoever runs it — why a model's answer or a
# form was refused, why the preset could not be read — in one place, so the
# suite asserts the wiring rather than the wording. Sourced, never executed.
#
# A refusal here is a reason the gate marks a question with when it sends it
# to the operator, so each says what was wrong in words a person reads cold.

# Loaded once, however many of the stand-in's parts source it: each load
# reads the file again, and one stop loaded this file 54 times, the loads
# together about a second of every stop (measured 2026-10-06).
[ -z "${STAND_IN_LOADED_WORDS:-}" ] || return 0
STAND_IN_LOADED_WORDS=1

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

refuse_marked_option_note() {
  printf 'The reader'\''s form holds the option "%s", which says it is recommended; the recommendation has its own field.\n' "$1"
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

refuse_no_step_note() {
  printf 'The reader'\''s form reports no step ended, so there is nothing to label.\n'
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

refuse_summary_part_empty_note() {
  printf 'The summary'\''s %s came back with no words.\n' "$1"
}

refuse_bad_problem_note() {
  printf 'The reader'\''s form holds a problem of the step that is not what was found and its state.\n'
}

refuse_state_outside_note() {
  printf 'The reader'\''s form gives a problem of the step the state "%s", which is not one of its words.\n' "$1"
}

refuse_proof_outside_note() {
  printf 'The reader'\''s form says the step'\''s proof "%s", which is not one of its words.\n' "$1"
}

refuse_from_outside_note() {
  printf 'The reader'\''s form says the next step comes from "%s", which is not one of its words.\n' "$1"
}

refuse_mark_outside_note() {
  printf 'The reader'\''s form marks the next step "%s", which is not one of its words.\n' "$1"
}

refuse_bad_step_number_note() {
  printf 'The reader'\''s form numbers the next step %s, which is no step'\''s number.\n' "$1"
}

refuse_no_step_but_note() {
  printf 'The reader'\''s form says the reply ends no step, yet says what a step found, proved or comes next.\n'
}

refuse_bad_major_note() {
  printf 'The sorter'\''s labelling of the step holds a major problem that is not the problem and its label.\n'
}

refuse_unknown_label_note() {
  printf 'The sorter labelled a problem "%s", which is no label it was handed.\n' "$1"
}

refuse_round_and_step_note() {
  printf 'The reader'\''s form says the reply both closes the round of questions and ends a step.\n'
}

refuse_bad_decision_note() {
  printf 'The round reader'\''s answer holds a decision that is not a number and a line.\n'
}

refuse_decision_outside_note() {
  printf 'The round reader numbered a decision %s, which is no decision of the round it was handed.\n' "$1"
}

refuse_decision_twice_note() {
  printf 'The round reader wrote decision %s more than once.\n' "$1"
}

refuse_decision_missing_note() {
  printf 'The round reader left out decision %s.\n' "$1"
}

# The names the refusals above call the forms by.
reader_form_words() { printf "reader's form"; }
sorter_answer_words() { printf "sorter's answer"; }
checker_answer_words() { printf "checker's answer"; }
reading_answer_words() { printf "cold second reading's answer"; }
matcher_answer_words() { printf "matcher's answer"; }
summary_answer_words() { printf "summary's answer"; }
step_sort_words() { printf "sorter's labelling of the step"; }
round_answer_words() { printf "round reader's answer"; }

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

# The routes the gate knows, already joined into one line.
refuse_kind_route_note() {
  printf 'The kind of question %s has the route "%s", which is none of the routes the stand-in knows: %s.\n' "$1" "$2" "$3"
}

refuse_go_kind_twice_note() {
  printf 'The stand-in preset holds more than one kind with the route %s in %s, so which of them a finished step is cannot be told.\n' "$1" "$2"
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

refuse_ladder_route_note() {
  printf 'The question the stand-in holds climbs the route "%s", which neither the ladder nor the light check is.\n' "$1"
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
# reason; then the summary's parts, the cold second reading where one ran
# standing before the operator's call.

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

# Why a question whose kind's recommendation stands unchallenged still came
# to the operator: it puts work off.
gate_defers_line() {
  printf -- '- The recommended option, %s, puts work off, which always comes to you.\n' "$1"
}

gate_unanswered_line() {
  printf -- '- The stand-in challenged the proposal ("%s"), and the reply neither drops it nor keeps it.\n' "$1"
}

# Why a question the sorter took for a step's report came to the operator: a
# reply that asks something is never one the stand-in says go to.
gate_go_kind_line() {
  printf -- '- The stand-in took it for a step'\''s report waiting for the go (%s), but it asks you something, so it is yours.\n' "$1"
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

# A question whose kind's recommendation stands with no challenge, brought
# while the kind is on trial: the decision asked for and what would have
# stood.
gate_accepted_note() {
  printf 'Stand-in: a question for you: %s\nThe stand-in would have accepted this: %s.\nWhy it came to you:\n%s' "$1" "$2" "$3"
}

# What the agent is told once the stand-in settles its question without the
# operator, given the option settled on.
gate_settled_note() {
  gate_from_note "go with your recommendation, \"$1\"."
}

# Why a question the stand-in would have settled came to the operator after
# all: it could not be logged, and nobody could list or reopen it.
gate_settle_unlogged_line() {
  printf -- '- The stand-in would have settled it on "%s" without you, but could not log it, so it is yours.\n' "$1"
}

gate_moved_line() {
  printf -- '- The agent'\''s answer did not hold under the stand-in'\''s challenges.\n'
}

gate_moved_then_held_line() {
  printf -- '- The agent'\''s answer did not hold under the stand-in'\''s challenges; after a bigger look around, asked again whether it was sure, it held.\n'
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

# The number of the answer given to "are you sure?" asked once more.
gate_sure_again_number() {
  printf '%s (asked again whether it was sure)' "$1"
}

# The summary's fixed parts, each under its heading, as the summary reader
# wrote them from the whole exchange.
gate_problem_part() {
  printf 'The problem:\n%s\n' "$1"
}

gate_first_recommendation_part() {
  printf 'What the agent first recommended:\n%s\n' "$1"
}

gate_what_moved_part() {
  printf 'What moved it, and why:\n%s\n' "$1"
}

gate_recommends_now_part() {
  printf 'What it recommends now:\n%s\n' "$1"
}

gate_operator_call_part() {
  printf 'Your call:\n%s\n' "$1"
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

# --- What the gate says of a step's report: the agent is sent back to fix
# what is left, or told to go on; the operator is told why the go is theirs,
# or, while the kind is on trial, that the stand-in would have said go.

# The go, as the log keeps what the stand-in approved and the settled list
# shows it.
step_go_words() {
  printf 'go'
}

gate_go_note() {
  gate_from_note 'go.'
}

gate_fix_first_note() {
  gate_from_note 'fix this before the next step.'
}

gate_ask_first_note() {
  gate_from_note 'ask the operator about this before the next step, as a question with its options and your recommendation:'
}

# Under the problems to fix, where some also need a decision.
gate_ask_first_heading() {
  printf 'Ask the operator about this before the next step, as a question with its options and your recommendation:\n'
}

gate_problem_line() {
  printf -- '- %s\n' "$1"
}

# The decision a step's report puts to the operator, given the next step as
# the reply names it, empty where it names none.
gate_step_question() {
  if [ -n "$1" ]; then
    printf 'Go on to the next step: %s?' "$1"
  else
    printf 'Go on to the next step?'
  fi
}

gate_step_operator_note() {
  printf 'Stand-in: the go is yours to give: %s\nWhy it came to you:\n%s' "$1" "$2"
}

gate_step_trial_note() {
  printf 'Stand-in: the stand-in would have said go: %s\nWhy it came to you:\n%s' "$1" "$2"
}

gate_fixed_heading() {
  printf 'Fixed in passing:\n'
}

# One major problem: the problem as the sorter named it, its label's name and
# words.
gate_major_line() {
  printf -- '- A major problem, which comes to you fixed or not: %s (%s: %s)\n' "$1" "$2" "$3"
}

gate_major_unsure_line() {
  printf -- '- The stand-in could not tell for certain whether a problem in the report is major, so it counts as major.\n'
}

gate_proof_failed_line() {
  printf -- '- The step'\''s proof did not pass.\n'
}

gate_proof_unsaid_line() {
  printf -- '- The report does not say the step'\''s proof passed.\n'
}

gate_new_work_line() {
  printf -- '- The next step it proposes is new work, not the brief'\''s own next step.\n'
}

gate_next_unsaid_line() {
  printf -- '- The report does not say the next step is the brief'\''s own next one.\n'
}

gate_no_brief_line() {
  printf -- '- The session holds no brief, so no next step is a brief'\''s own.\n'
}

gate_briefs_unknown_line() {
  printf -- '- Which brief the session holds could not be told, so whether the next step is the brief'\''s own cannot be either.\n'
}

gate_first_step_line() {
  printf -- '- The next step is the brief'\''s first, whose go is always yours.\n'
}

gate_step_number_unsaid_line() {
  printf -- '- The report does not say which of the brief'\''s steps comes next, so whether it is the first cannot be told.\n'
}

# What the next step does that makes its go always the operator's, given the
# mark's words.
gate_step_mark_line() {
  printf -- '- The next step %s, so its go is always yours.\n' "$1"
}

# The words of each mark the reader may put on the next step.
step_mark_words() {
  case "$1" in
    pushes) printf 'pushes' ;;
    syncs) printf 'syncs repositories' ;;
    deletes) printf 'deletes something' ;;
    other-session) printf 'touches another session'\''s work' ;;
    runs-alone) printf 'is one the brief runs alone at a quiet moment' ;;
    *) printf '%s' "$1" ;;
  esac
}

# What each of the two labels the code adds to the preset's risks means, as
# the sorter is handed it and the operator reads it.
step_lost_data_words() {
  printf 'Lost data: something that was stored is gone or damaged.'
}

step_broken_check_words() {
  printf 'A check that passed before now fails.'
}

# --- The round's decisions, laid out when the agent asks to start building.

# The decision the request puts to the operator, as the log keeps it.
gate_round_question() {
  printf 'Start building, with every decision of the round as listed?'
}

# Why it came to them, as the log keeps it.
gate_round_why_line() {
  printf -- '- The agent asks to start building, which is always yours to say.\n'
}

round_heading() {
  printf 'Stand-in: the agent asks to start building, which is always yours to say. Every decision of this round:\n'
}

# One decision, by its number in the log, who decided it, and what was decided.
round_item_line() {
  printf '%s. %s: %s\n' "$1" "$2" "$3"
}

# Who decided, as each line names them to the operator.
round_by_operator_words() {
  printf 'You'
}

round_by_stand_in_words() {
  printf 'Stand-in'
}

round_empty_line() {
  printf 'No decision was made in this round.\n'
}

# The round reader failed: each decision is shown as the log keeps it, under
# a line saying why.
round_failed_note() {
  printf 'The plain list could not be written, so these are the questions as asked. Why:\n%s\n' "$1"
}

round_answered_words() {
  printf '%s (you answered: %s)' "$1" "$2"
}

round_unanswered_words() {
  printf '%s (no answer of yours was kept)' "$1"
}

round_settled_words() {
  printf '%s (settled on: %s)' "$1" "$2"
}

round_hint() {
  printf 'Say "go" to start the first step, or "reopen" and a number to bring that decision back as a normal question; building waits until every reopened one is settled again.\n'
}

# Who decided, as the round reader is handed it.
round_by_operator_prompt_words() {
  printf 'Decided by the operator. Their answer: %s' "$1"
}

round_unanswered_prompt_words() {
  printf 'It reached the operator, and no answer of theirs was kept.'
}

round_by_stand_in_prompt_words() {
  printf 'Decided by the stand-in, without the operator. It settled on: %s' "$1"
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

# A decision of a round the operator made themselves, reopened from the
# round's list: number, when it reached them, and where.
reopen_decided_heading() {
  printf 'Stand-in: question %s, which you decided, is open again.\nIt reached you at %s, %s.\n' "$1" "$2" "$3"
}

reopen_answered_line() {
  printf 'You answered: %s\n' "$1"
}

reopen_unanswered_line() {
  printf 'No answer of yours was kept.\n'
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

# The note for a reopened go: number, and the decision as the log keeps it.
reopen_go_agent_note() {
  printf 'The stand-in'\''s question %s, a go to the next step it gave without the user, has been shown to the user above, in full. It is open again: do not start that step; ask the user now, in plain conversation, whether to go on with it, and wait for their answer. The decision: %s\n' "$1" "$2"
}

reopen_fixed_heading() {
  printf 'Fixed in passing before the go:\n'
}

reopen_usage_note() {
  printf 'The stand-in reopens a question by the number its settled list or a round'\''s list shows, as in "reopen 3"; add "exchange" after the number to read every turn word for word.\n'
}

reopen_nothing_note() {
  printf 'There is nothing to reopen: nothing was settled without you, since every kind is still on trial, and no round'\''s list was laid out before building.\n'
}

reopen_unknown_note() {
  printf 'No question the stand-in can reopen is numbered %s; its settled list and the round lists show the numbers there are.\n' "$1"
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

# A decision the user made, reopened from a round's list: number, question as
# first asked, its options joined, and their answer as kept (empty for none).
reopen_decided_agent_note() {
  printf 'The stand-in'\''s question %s, which the user had decided, has been shown to the user above, in full. It is open again: ask the user it now as a normal question in plain conversation, with its options and your recommendation, and wait for their answer. The question as first asked: %s Its options: %s. The user had answered: %s\n' "$1" "$2" "$3" "$4"
}

# Under the note for a decision listed in a round, laid out before building:
# building waits until every reopened one is settled again (settled
# 2026-10-06).
reopen_round_waits_note() {
  printf 'It is a decision of the round laid out before building, so building waits: do not start building, or go on with it, until it is settled again; then ask the user again whether to start building.\n'
}

skill_name_unreadable_note() {
  printf 'The stand-in'\''s skill hook cannot read the skill'\''s name from %s.\n' "$1"
}

# --- The switch.

refuse_switch_unwritable_note() {
  printf 'The stand-in'\''s switch cannot be written in %s.\n' "$1"
}

refuse_switch_unremovable_note() {
  printf 'The stand-in'\''s switch %s cannot be removed.\n' "$1"
}

# --- The command that starts the stand-in. What the operator is shown opens
# with "Stand-in:", as every message the gate brings them does.

refuse_start_usage_note() {
  printf 'Type /%s with the name of one brief to start it, with %s to switch the stand-in on with no brief, or with nothing to see the briefs to pick from.\n' "$1" "$2"
}

organizer_unrunnable_note() {
  printf 'The work organizer cannot be run: %s is not an executable file.\n' "$1"
}

# A refusal: the prompt never reaches the model, and the reasons follow as the
# part that refused gave them, the organizer's own words among them.
start_refused_note() {
  local why="$1"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'Stand-in: not started, and nothing was switched on. Why:\n%s\n' "$why"
}

# Under a refusal, where the switch this command wrote could not be taken
# back: the stand-in stays on for the session with no brief taken.
start_switch_left_line() {
  printf 'The stand-in'\''s switch for this session could not be removed, so the stand-in is on for this session with no brief taken. Why:\n%s\n' "$1"
}

start_brief_shown_note() {
  printf 'Stand-in: on for this session, working on %s.\n' "$1"
}

start_session_shown_note() {
  printf 'Stand-in: on for this session, with no brief taken.\n'
}

# The model's note for the brief form: the brief, where the opener was read
# from, and the opener whole.
start_brief_agent_note() {
  printf 'The user started this session under the stand-in, working on the brief %s, which the work organizer has taken for this session. Before anything else, follow the stand-in'\''s opener below, read from %s; what it names sits beside it.\n\n%s\n' "$1" "$2" "$3"
}

start_session_agent_note() {
  printf 'The user switched the stand-in on for this session, with no brief taken.\n'
}

start_list_agent_note() {
  printf 'The work organizer'\''s list of briefs (%s lines) has been shown to the user above, exactly as printed. Nothing was taken, and the stand-in was not switched on.\n' "$1"
}

# --- The session's end.

refuse_end_session_note() {
  printf 'The session-end event carries no session id the stand-in can use, so no switch was removed.\n'
}

end_not_removed_note() {
  printf 'The stand-in'\''s session-end hook could not remove the switch of session %s.\n' "$1"
}
