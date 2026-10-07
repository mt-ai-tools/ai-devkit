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

refuse_bad_finding_note() {
  printf 'The closing reader'\''s form holds a finding that is not what was found, its sort, its files and a brief.\n'
}

refuse_sort_outside_note() {
  printf 'The closing reader'\''s form sorts a finding "%s", which is not one of its words.\n' "$1"
}

refuse_unsorted_note() {
  printf 'The agent gave no sort for something it found: %s.\n' "$1"
}

refuse_file_outside_note() {
  printf 'The closing reader'\''s form names the file %s, which is no path inside the project root.\n' "$1"
}

refuse_brief_outside_note() {
  printf 'The closing reader'\''s form hands a finding to the brief "%s", which no other session holds.\n' "$1"
}

refuse_brief_unasked_note() {
  printf 'The closing reader'\''s form names the brief "%s" for a finding it does not hand off.\n' "$1"
}

refuse_quick_no_files_note() {
  printf 'The agent would fix "%s" in passing but names no file it touches, so where it lies cannot be checked.\n' "$1"
}

refuse_left_but_here_note() {
  printf 'The closing reader'\''s form says nothing is left for the brief, yet holds a finding that belongs to it.\n'
}

refuse_here_none_but_left_note() {
  printf 'The closing reader'\''s form says something is left for the brief, yet holds no finding that belongs to it.\n'
}

refuse_case_skipped_but_note() {
  printf 'The case-writer'\''s form says the answer does not answer the question, yet holds a case.\n'
}

refuse_case_part_empty_note() {
  printf 'The case-writer'\''s form says the answer answers the question, but its %s has no words.\n' "$1"
}

refuse_case_line_note() {
  printf 'The case-writer'\''s %s runs over more than one line, so it cannot stand in a case'\''s header.\n' "$1"
}

refuse_case_marker_note() {
  printf 'The case-writer'\''s reply holds a line the case file marks its reply with, so the reply could not be told apart in it.\n'
}

refuse_case_option_note() {
  printf 'The case-writer'\''s form holds an option that is not a short label.\n'
}

refuse_case_options_few_note() {
  printf 'The case-writer'\''s form holds fewer than two options, so there is nothing the operator chose between.\n'
}

refuse_case_recommended_note() {
  printf 'The case-writer'\''s form recommends "%s", which is not among its options.\n' "$1"
}

refuse_case_picked_note() {
  printf 'The case-writer'\''s form says the operator picked "%s", which is not among its options.\n' "$1"
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
look_form_words() { printf "closing reader's form"; }
case_form_words() { printf "case-writer's form"; }
secret_answer_words() { printf "secret check's answer"; }

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

# The two waits' commands, then the case-writer's and the exam's, as the
# agent types them.
refuse_usage_note() {
  printf 'Usage: read-reply (the reply on stdin) | sort <reader form> (the reply on stdin) | %s <brief> | %s <path> | %s | %s\n' "$1" "$2" "$3" "$4"
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

refuse_state_unremovable_note() {
  printf 'The stand-in'\''s record %s cannot be removed.\n' "$1"
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
# for, as the agent asked it, then why it came to them, one line per reason;
# then the summary's parts, the cold second reading where one ran standing
# before the operator's call.

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

# Why a question came to the operator though its kind and route would not
# have brought it: they reopened a decision, given its number.
gate_reopened_line() {
  printf -- '- You reopened question %s, so the next question this session asks is yours, whatever its kind.\n' "$1"
}

# Why a step's report came to the operator while a decision they reopened
# waits to be asked again, given its number.
gate_reopened_step_line() {
  printf -- '- You reopened question %s, and this session has not asked it again yet, so the go is yours until it has.\n' "$1"
}

# A proposal the agent dropped under the stand-in's challenge whose line
# could not be written, given the question: the reply stops unjudged.
gate_drop_unlogged_note() {
  printf 'Stand-in: the agent dropped a proposal under the stand-in'\''s challenge, but the drop could not be logged, so it would be listed nowhere and could not be reopened. The proposal: %s\nThe rest of the reply was not judged, so it is yours to read.\n' "$1"
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

# --- The closing loop: the sweep after the work is done, in rounds of two
# looks, until a round finds nothing that belongs to the brief.

# Under each look, how the agent reports, given the sort words in the
# filter's order: here, written down, not the same job, quick, hand-off,
# park. It reports first and changes nothing, since a fix made in the same
# reply could not be held back once code found it belongs to someone else.
closing_report_note() {
  printf 'Report what you find, and change nothing yet. For each finding, say what it is, name the files it touches, and give it one of these sorts:\n'
  printf -- '- %s: it belongs to this brief (its summary and what it touches).\n' "$1"
  printf -- '- %s: it belongs elsewhere and is already written down, in another brief or the notes.\n' "$2"
  printf -- '- %s: the new thing could also be used there, but it is not the same job.\n' "$3"
  printf -- '- %s: written down nowhere, needs no decision, a few lines in one module, and nobody else'\''s uncommitted edits in its files.\n' "$4"
  printf -- '- %s: a place to use the new thing in an area another session is working in; name that session'\''s brief.\n' "$5"
  printf -- '- %s: anything else.\n' "$6"
  printf 'Then say plainly whether anything that belongs to this brief is left.\n'
}

closing_here_note() {
  gate_from_note 'the closing sweep found work that belongs to this brief. Ask the operator about each, one question at a time, with its options and your recommendation, and do it once it is decided:'
}

closing_swept_note() {
  gate_from_note 'the closing sweep came back with nothing that belongs to this brief.'
}

# Under the round's tasks, once the stand-in finished the briefs, over the
# paths finishing printed, given the case-writer's command as the agent types
# it: run in the foreground before the commit, since its cases are committed
# with the paths finishing printed (settled 2026-10-07).
closing_commit_line() {
  printf 'The stand-in has finished the brief through the work organizer, which changed the paths below. First run `%s` in the foreground: it writes the test cases of the brief from the operator'\''s answers, and prints each case file it wrote. Then commit exactly the paths below and the case files it printed, run the project'\''s full check, and say plainly that the brief is done, what it built, and whether the full check passed:\n' "$1"
}

closing_finish_failed_note() {
  local why="$1"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'Stand-in: the closing sweep came back with nothing that belongs to the brief, but finishing it through the work organizer failed, so it is yours. Why:\n%s\n' "$why"
}

closing_finish_partial_heading() {
  printf 'What the work organizer changed before it failed, still to be committed:\n'
}

closing_round_findings_heading() {
  printf 'This round'\''s findings:\n'
}

closing_quick_heading() {
  printf 'Fix these in passing:\n'
}

closing_hand_off_heading() {
  printf 'Write a hand-off for each into the brief named, and leave its code alone:\n'
}

closing_park_heading() {
  printf 'Park each as a line in the notes, or ask the operator whether to write a brief for it:\n'
}

# A finding handed off, given what it is, the briefs it goes into, joined,
# and why it was not fixed in passing, empty where the agent sorted it so.
closing_hand_off_line() {
  if [ -n "${3:-}" ]; then
    printf -- '- %s (into %s; not fixed in passing: %s)\n' "$1" "$2" "$3"
  else
    printf -- '- %s (into %s)\n' "$1" "$2"
  fi
}

# The briefs a finding goes into, joined, as the operator reads them.
closing_into_words() {
  printf 'into %s' "$1"
}

# A finding the agent would have fixed in passing that code moved, given what
# it is and why.
closing_moved_line() {
  printf -- '- %s (not fixed in passing: %s)\n' "$1" "$2"
}

closing_moved_held_words() {
  printf 'another session works there'
}

closing_moved_uncommitted_words() {
  printf 'its files hold changes nobody committed'
}

# What each sort is called where the operator reads a round.
closing_sort_words() {
  case "$1" in
    here) printf 'belongs to this brief' ;;
    written-down) printf 'already written down elsewhere, dropped' ;;
    not-same-job) printf 'not the same job, dropped' ;;
    quick) printf 'fixed in passing' ;;
    hand-off) printf 'handed off' ;;
    park) printf 'parked' ;;
    *) printf '%s' "$1" ;;
  esac
}

# One finding as the operator reads it: what it is, and its sort's words.
closing_finding_line() {
  printf -- '- %s (%s)\n' "$1" "$2"
}

# The decision a round puts, as the log keeps it, given its number.
closing_round_question() {
  printf 'Closing sweep, round %s: is anything left that belongs to the brief?' "$1"
}

closing_notice_note() {
  printf 'Stand-in: the closing sweep has found something that belongs to this brief in %s rounds, so it is yours to look at. This round'\''s findings:\n' "$1"
}

# Why the round came to the operator, as the log keeps it.
closing_notice_why_line() {
  printf -- '- The closing sweep found something that belongs to the brief in %s rounds, which comes to you.\n' "$1"
}

closing_unlogged_note() {
  printf 'Stand-in: round %s of the closing sweep could not be logged, so its rounds cannot be counted, and it is yours. Its findings:\n' "$1"
}

closing_briefs_unknown_note() {
  local why="$1"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'Stand-in: the agent says the work is done, but which brief this session holds could not be told, so the closing sweep was not started. Why:\n%s\n' "$why"
}

# --- The end report, shown once the closing sweep came back empty and the
# brief was finished.

end_report_heading() {
  printf 'Stand-in: the closing sweep came back empty, and %s is finished. The end report:\n' "$1"
}

end_built_line() {
  printf 'What was built: in the agent'\''s own words, in its reply above.\n'
}

end_check_passed_line() {
  printf 'The full check: the agent says it passed.\n'
}

end_check_failed_line() {
  printf 'The full check: the agent says it failed, or could not be run.\n'
}

end_check_unsaid_line() {
  printf 'The full check: the agent does not say it passed.\n'
}

# Where the agent's last reply could not be read: why, as the reader said.
end_check_unread_line() {
  local why="$1"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'The full check: the agent'\''s reply could not be read, so whether it passed is not known. Why:\n%s\n' "$why"
}

end_silent_heading() {
  printf 'Decided without you:\n'
}

# One decision settled without the operator: its number, the question as the
# agent retold it where its line kept a retelling, as asked otherwise, and the
# option settled on.
end_silent_line() {
  printf -- '- %s. %s Settled on: %s. Say "reopen %s" to bring it back.\n' "$1" "$2" "$3" "$1"
}

end_dropped_heading() {
  printf 'Dropped:\n'
}

# One proposal the agent dropped under the stand-in's challenge: its number
# and the question.
end_dropped_line() {
  printf -- '- %s. %s (the agent dropped it under the stand-in'\''s challenge; say "reopen %s" to bring it back)\n' "$1" "$2" "$1"
}

end_parked_heading() {
  printf 'Parked:\n'
}

# Over the paths the work organizer printed as it finished the brief.
end_freed_heading() {
  printf 'Finished through the work organizer, which changed these paths: the brief removed, and every brief that waited on it freed of that wait:\n'
}

end_none_line() {
  printf -- '- None.\n'
}

# The test cases written from the brief's answers: how many were written,
# skipped as no clear answer, held back for holding something secret, and not
# written because the writer or a check could not run. Never what was held
# back: saying it would repeat the secret where the case was kept from it.
end_cases_line() {
  printf 'Test cases: %s written, %s skipped as no clear answer, %s held back for holding something secret, %s not written because the case-writer or a secret check could not run.\n' "$1" "$2" "$3" "$4"
}

end_cases_never_line() {
  printf 'Test cases: the case-writer never ran, so no case was written from this brief'\''s answers.\n'
}

# --- The case-writer, run by the agent once the brief is finished.

# Handed to the case-writer where the log kept no part of the kind asked for.
case_none_kept_words() {
  printf '(none kept)'
}

# A case's yes and no, as its header writes them.
case_yes_words() { printf 'yes'; }
case_no_words() { printf 'no'; }

# A case's header value where the log kept no kind, and its tuning mark while
# no prompt was adjusted on it.
case_kind_unknown_words() { printf 'unknown'; }
case_tuning_none_words() { printf 'none'; }

# A case's why where the operator and the exchange gave none.
case_no_why_words() {
  printf 'No reason was given.'
}

refuse_cases_session_note() {
  printf 'The environment carries no session id in %s, so which session'\''s finished brief to write cases for cannot be told; run it from inside the session.\n' "$1"
}

refuse_cases_unfinished_note() {
  printf 'No brief was finished in this session since its last turn, so there is no brief to write cases for; it runs once the stand-in has finished the brief.\n'
}

refuse_cases_unwritable_note() {
  printf 'A test case cannot be written in %s.\n' "$1"
}

refuse_case_bad_id_note() {
  printf 'The question log holds a line whose id, "%s", cannot name a case, so its case was not written.\n' "$1"
}

# Why one case was not written, given the question's number in the log: the
# reasons follow as the failing part gave them, none of them quoting the case.
refuse_case_unwritten_note() {
  printf 'The case of question %s was not written:\n' "$1"
}

refuse_scanner_unrun_note() {
  printf 'The secret scanner, %s, could not be run through mise (status %s); install it with: mise install %s\n' "$1" "$2" "$1"
}

refuse_scanner_folder_note() {
  printf 'The secret scanner was given no empty folder to run in, so files it reads from its folder could not be kept away from it.\n'
}

refuse_changes_unknown_note() {
  printf 'Whether %s holds changes nobody committed cannot be told: git could not read it.\n' "$1"
}

# --- The wait on another session's work, and the look around once it is
# over.

refuse_wait_session_note() {
  printf 'The environment carries no session id in %s, so the wait cannot be marked as this session'\''s; run it from inside the session.\n' "$1"
}

refuse_wait_no_brief_note() {
  printf 'This session holds no brief, so there is none to write the wait into.\n'
}

refuse_repository_missing_note() {
  printf 'The path "%s" is no folder inside the project root, so there is no repository there to wait on.\n' "$1"
}

refuse_repository_unreadable_note() {
  printf 'Whether %s holds uncommitted or unpushed work cannot be told: git could not read it.\n' "$1"
}

refuse_repository_no_upstream_note() {
  printf '%s has no upstream to compare with (its branch tracks none, or it is on no branch), so whether its commits are pushed cannot be told.\n' "$1"
}

refuse_woken_unreadable_note() {
  printf 'The mark of this session'\''s wait, %s, cannot be read.\n' "$1"
}

refuse_woken_unwritable_note() {
  printf 'The mark of a session'\''s wait cannot be written in %s.\n' "$1"
}

refuse_woken_unremovable_note() {
  printf 'The mark of this session'\''s wait, %s, cannot be removed.\n' "$1"
}

# What a wait was for, given the brief waited for, or the repository's path.
wait_brief_words() {
  printf 'the brief %s to be finished' "$1"
}

wait_repository_words() {
  printf '%s to hold nothing uncommitted and nothing unpushed' "$1"
}

# Over the paths the organizer printed as the wait was written.
wait_written_line() {
  printf 'The wait is written into the briefs at these paths:\n'
}

# Given what the wait was for.
wait_over_note() {
  printf 'The wait is over: it was for %s.\n' "$1"
}

# Under the look around the woken session is sent: what to report, and that
# the go is the operator's.
resume_report_note() {
  printf 'Report what the other session landed, and which of the answers given before the wait may no longer hold. Ask again any decision it shook, one at a time, as a question with its options and your recommendation. Then wait for the operator'\''s go: build nothing until they give it.\n'
}

# Under the session's report, given what the wait was for.
resume_reported_note() {
  printf 'Stand-in: this session waited for %s. The wait is over, and its look around is above: what landed, and which earlier answers may no longer hold. The go is yours: it builds nothing until you give it.\n' "$1"
}

# Where the wait could not be watched, given what it was for and why.
resume_refused_note() {
  local why="$2"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'Stand-in: this session waited for %s, but the wait could not be watched, so it is yours. Why:\n%s\n' "$1" "$why"
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

# One question: its number, and the question as the agent retold it where its
# line kept a retelling, as asked otherwise.
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

# A proposal the agent dropped under the stand-in's challenge: number, when
# it was dropped, and where.
reopen_dropped_heading() {
  printf 'Stand-in: question %s, a proposal the agent dropped under the stand-in'\''s challenge, is open again.\nIt was dropped at %s, %s.\n' "$1" "$2" "$3"
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
  printf 'The stand-in reopens a question by the number its settled list, a round'\''s list or its end report shows, as in "reopen 3"; add "exchange" after the number to read every turn word for word.\n'
}

reopen_nothing_note() {
  printf 'There is nothing to reopen: nothing was settled without you, since every kind is still on trial, no proposal was dropped, and no round'\''s list was laid out before building.\n'
}

reopen_unknown_note() {
  printf 'No question the stand-in can reopen is numbered %s; its settled list, the round lists and its end reports show the numbers there are.\n' "$1"
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

# A proposal the agent dropped under the stand-in's challenge, reopened:
# number, question as first asked, its options joined, and the option the
# agent recommended then (empty for none).
reopen_dropped_agent_note() {
  printf 'The stand-in'\''s question %s, a proposal the agent dropped under the stand-in'\''s challenge, has been shown to the user above, in full. It is open again: ask the user it now as a normal question in plain conversation, with its options and your recommendation, and wait for their answer. The question as first asked: %s Its options: %s. The agent had recommended: %s.\n' "$1" "$2" "$3" "$4"
}

# Under the note for a decision listed in a round, laid out before building:
# building waits until every reopened one is settled again (settled
# 2026-10-06).
reopen_round_waits_note() {
  printf 'It is a decision of the round laid out before building, so building waits: do not start building, or go on with it, until it is settled again; then ask the user again whether to start building.\n'
}

refuse_skill_session_note() {
  printf 'The skill'\''s event carries no session id the stand-in can use.\n'
}

# A reopen refused because the session could not be marked to bring its next
# question to the user: the number, and why, as the failing part said.
reopen_unmarked_note() {
  local why="$2"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'Stand-in: question %s was not reopened: this session could not be marked to bring its next question to you, so asked again it could be settled without you. Why:\n%s\n' "$1" "$why"
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
# from, the opener whole, and the stand-in's entry with its two waits'
# commands, which the opener names by role alone.
start_brief_agent_note() {
  printf 'The user started this session under the stand-in, working on the brief %s, which the work organizer has taken for this session. Before anything else, follow the stand-in'\''s opener below, read from %s; what it names sits beside it.\n\n%s\n\nThe stand-in'\''s wait, as a background command: `%s %s <brief>` waits for that brief to be finished; `%s %s <path>` waits for the repository at that path, from the project root, to hold nothing uncommitted and nothing unpushed.\n' "$1" "$2" "$3" "$4" "$5" "$4" "$6"
}

start_session_agent_note() {
  printf 'The user switched the stand-in on for this session, with no brief taken.\n'
}

start_list_agent_note() {
  printf 'The work organizer'\''s list of briefs (%s lines) has been shown to the user above, exactly as printed. Nothing was taken, and the stand-in was not switched on.\n' "$1"
}

# --- The session's end.

refuse_end_session_note() {
  printf 'The session-end event carries no session id the stand-in can use, so no switch or record was removed.\n'
}

# Under the reasons, which name the switch or the record left behind.
end_not_removed_note() {
  printf 'The stand-in'\''s session-end hook could not remove everything of session %s.\n' "$1"
}

# --- The question box. Questions stay in the reply in a session the stand-in
# is on for: the gate reads only the reply, so a question asked in the box
# would pass it unseen (settled 2026-10-06).

refuse_tool_session_note() {
  printf 'The before-tool event carries no session id the stand-in can use.\n'
}

# To the agent, in the tool's place: the question tool's name.
question_box_refused_note() {
  gate_from_note "$(printf 'do not use the %s tool in this session. Ask your question in your reply instead, in plain conversation, with its options and your recommendation, so the stand-in reads it.' "$1")"
}

# To the operator, where whether the stand-in is on cannot be told and the
# box is let through: the reasons the failing part gave.
question_box_unjudged_note() {
  local why="$1"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'Stand-in: whether it is on for this session cannot be told, so the question box was let through, and the stand-in will not read its question. Why:\n%s\n' "$why"
}

# --- The exam: every test case replayed against the stand-in as it stands,
# owed by a session that edited what the stand-in judges by.

# A case's tuning mark, as its header writes it once a prompt was adjusted on
# it.
case_tuning_used_words() { printf 'used'; }

# Where a replayed case was sent, as the exam names it: back to the agent, to
# the operator, or settled by the stand-in without them.
exam_route_words() {
  case "$1" in
    agent) printf 'back to the agent' ;;
    operator) printf 'to the operator' ;;
    *) printf 'settled by the stand-in alone' ;;
  esac
}

# The parts a fault can name, as the operator reads them.
exam_reader_words() { printf 'reader'; }
exam_checker_words() { printf 'rules and conventions check'; }
exam_sorter_words() { printf 'sorter'; }
exam_labeller_words() { printf "step's labeller"; }
exam_preset_words() { printf 'preset'; }

# What a case is read as, as the faults name it.
exam_question_words() { printf 'a question to the operator'; }
exam_step_words() { printf "a step's report waiting for the go"; }

# Under a case's name where its tuning is used: replayed, never scored.
exam_tuning_used_words() {
  printf ' (tuning used: replayed, never counted toward a score)'
}

# One case's outcome, given its name, the tuning words (empty for none) and,
# for a passed one, where it was sent.
exam_passed_line() {
  printf 'Passed: %s%s, sent %s.\n' "$1" "$2" "$(exam_route_words "$3")"
}

exam_dropped_line() {
  printf 'Dropped: %s%s. It passed the last passing exam, so it blocks the change.\n' "$1" "$2"
}

exam_dropped_unknown_line() {
  printf 'Dropped: %s%s. No last results are kept, so whether it passed before cannot be told, and it blocks the change.\n' "$1" "$2"
}

exam_failed_new_line() {
  printf 'Failed: %s%s. It never passed an exam before, so it does not block the change.\n' "$1" "$2"
}

# A fault or a note under its case's line.
exam_detail_line() {
  printf -- '  - %s\n' "$1"
}

# The faults a replay can find, each one line.
exam_part_failed_fault() {
  printf 'The %s gave no answer it could be judged on: %s' "$1" "$2"
}

exam_misread_fault() {
  printf 'The reader did not read it as %s, as the case says it is.' "$1"
}

exam_finding_missing_fault() {
  printf 'The rules and conventions check did not find what the case expects: %s.' "$1"
}

# Given the entries the case says it breaks, joined.
exam_breaks_none_fault() {
  printf 'The rules and conventions check named none of the entries the case says it breaks: %s.' "$1"
}

# Under a replayed case's line: how many of its replays passed.
exam_replays_line() {
  printf -- '  - %s of %s replays passed.\n' "$1" "$2"
}

# A replay that ended without a result, with what it said on the way out.
exam_replay_stopped_fault() {
  local why="$1"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'A replay stopped before it gave a result: %s' "$why"
}

# The exam's last line, given how long it ran, in whole seconds.
exam_time_line() {
  printf 'The exam took %s s.\n' "$1"
}

exam_kind_fault() {
  printf 'The sorter sorted it as %s; the case is %s.' "$1" "$2"
}

exam_route_fault() {
  printf 'It was sent %s; the case expects it sent %s.' "$(exam_route_words "$1")" "$(exam_route_words "$2")"
}

exam_route_alone_fault() {
  printf 'It would have been settled without the operator, who did not take the agent'\''s recommendation.'
}

exam_unjudgeable_fault() {
  printf 'The case cannot be judged: %s' "$1"
}

# Why a case cannot be judged.
exam_case_no_reply_words() {
  printf 'it holds no reply between its two marker lines.'
}

exam_case_bad_route_words() {
  printf 'it expects the route "%s", which is none the exam knows (agent, operator, alone).' "$1"
}

exam_case_no_expectation_words() {
  printf 'it says neither where it must be sent nor whether the operator picked the recommended option.'
}

exam_case_bad_finding_words() {
  printf 'it expects the finding "%s", which the rules and conventions check never gives.' "$1"
}

exam_case_unreadable_words() {
  printf 'the file cannot be read.'
}

# The notes a replay leaves where it could not run a part as the gate would.
exam_challenged_note() {
  printf 'Its kind, %s, is challenged first, which sends it back to the agent; the agent'\''s answer to the challenge is not replayed.' "$1"
}

exam_climb_unreplayed_note() {
  printf 'Its kind'\''s route, %s, climbs on the agent'\''s later replies, which the case does not hold, so the matcher was not run and the answer is taken as held.' "$1"
}

# The exam's last lines, given how many cases were replayed, passed and
# failed, and for a failed exam how many dropped.
exam_passed_note() {
  printf 'The exam passed: %s cases, %s passed, %s failed, none dropped.\n' "$1" "$2" "$3"
}

exam_failed_note() {
  printf 'The exam failed: %s cases, %s passed, %s failed, %s dropped. Each drop blocks the change until it passes again.\n' "$1" "$2" "$3" "$4"
}

exam_no_results_line() {
  printf 'No last results of a passing exam are kept on this machine, so every failing case counts as a drop.\n'
}

exam_mark_cleared_line() {
  printf 'This session'\''s exam owed is cleared.\n'
}

exam_mark_kept_line() {
  printf 'This session'\''s exam owed stands: its step reports and its "brief done" wait until an exam passes.\n'
}

exam_mark_moved_line() {
  printf 'An edit of what the stand-in judges by was noted while the exam ran, so this session'\''s exam owed stands; run the exam again.\n'
}

exam_no_session_line() {
  printf 'The environment names no session, so no session'\''s exam owed was cleared.\n'
}

refuse_exam_session_note() {
  printf 'The environment'\''s %s holds no session id the stand-in can use, so whose exam owed to clear cannot be told.\n' "$1"
}

refuse_exam_no_cases_note() {
  printf 'No test case is kept in %s, so the exam has nothing to replay and cannot pass.\n' "$1"
}

refuse_exam_results_unreadable_note() {
  printf 'The last results of a passing exam, %s, cannot be read, so which case dropped cannot be told.\n' "$1"
}

refuse_exam_results_unwritable_note() {
  printf 'The results of the passing exam cannot be kept in %s, so the next exam could not tell a drop; this exam is not taken as passed.\n' "$1"
}

# --- The exam owed: the mark an edit of what the stand-in judges by leaves.

refuse_owed_unreadable_note() {
  printf 'This session'\''s exam owed, %s, cannot be read.\n' "$1"
}

refuse_owed_unwritable_note() {
  printf 'A session'\''s exam owed cannot be written in %s.\n' "$1"
}

refuse_owed_unremovable_note() {
  printf 'This session'\''s exam owed, %s, cannot be removed.\n' "$1"
}

refuse_edit_session_note() {
  printf 'The after-tool event carries no session id the stand-in can use.\n'
}

refuse_edit_path_note() {
  printf 'The after-tool event names no file the tool edited.\n'
}

# The files the session edited, one a line, under the words sent.
owed_file_line() {
  printf -- '- %s\n' "$1"
}

# To the agent, in a session the stand-in is on for: its step's report or its
# "brief done", sent back; given the exam's command and the files, one a line.
gate_exam_owed_note() {
  gate_from_note "$(printf 'run the exam first. This session edited what the stand-in judges by, so its step reports and its "brief done" wait until the exam passes. Run it, then report again:\n%s' "$1")"
  printf 'Edited:\n%s' "$2"
}

# To the operator, once the report was sent back as often as it may be; given
# how often, the exam's command and the files, one a line.
gate_exam_owed_operator_note() {
  printf 'Stand-in: this session edited what the stand-in judges by, and was sent back %s times to run the exam, which has not passed since. The report above is yours to weigh. The exam runs by:\n%s\nEdited:\n%s' "$1" "$2" "$3"
}

# To the agent each turn, in a session the stand-in is off for; given the
# exam's command and the files, one a line.
exam_reminder_note() {
  gate_from_note "$(printf 'an exam is owed. This session edited what the stand-in judges by; run the exam before you report a step or say the brief is done, and say what it showed:\n%s' "$1")"
  printf 'Edited:\n%s' "$2"
}

# To the operator, where an edit could not be checked for whether it owes the
# exam, with why.
edit_unnoted_note() {
  local why="$1"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'Stand-in: an edit could not be checked for whether it owes the exam, so no exam is asked for it. Why:\n%s\n' "$why"
}

# To the operator and the agent, where whether an exam is owed cannot be told
# at the start of a turn, with why.
exam_reminder_unread_note() {
  local why="$1"
  [ -n "$why" ] || why='No part of the stand-in said why.'
  printf 'Stand-in: whether this session owes the exam cannot be told, so no reminder could be given. Why:\n%s\n' "$why"
}
