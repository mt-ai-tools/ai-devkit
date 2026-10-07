#!/usr/bin/env bash
# Claude Code Stop hook — the stand-in's gate, a thin orchestrator: at the end
# of every reply in a session the stand-in is switched on for, the reply is
# read into a form; a question to the operator is checked against the
# project's rules and conventions, sorted, challenged where its kind carries
# a challenge, and routed — back to the agent, on to the operator, up the
# challenge ladder, through the light check's one "are you sure?", or
# accepted as it stands. A reply that reports a step finished and asks nothing
# is weighed for the operator's go to the next step: the go said, the agent
# sent back to fix what is left, or the report brought to the operator with
# why. A reply that closes the round of questions and asks to start building
# reaches the operator with every decision of the round laid out. A reply
# saying the work is done starts the closing loop: rounds of two looks around,
# each look's findings checked in code and sorted, until a round finds nothing
# that belongs to the brief; the brief is then finished through the work
# organizer, and the agent's reply after committing what that changed brings
# the operator the end report. A session whose wait on another session's work
# is over is sent the preset's resume look-around, and its report reaches the
# operator for the go. In every other session it does nothing at all.
#
# A proposal the agent drops under its kind's challenge is a line of the log,
# listed in the end report and reopenable. A decision the operator reopened
# marks the session's record, and the session's next question reaches them
# whatever its kind and route; until it has, no go is given on a step's
# report either.
#
# The order is the point: the rules and conventions check runs before any
# route, so a question that breaks one never reaches the operator; the
# challenge runs before the routes, so a proposal the agent drops is never
# asked about; a reopened mark is read before both, so a decision the operator
# asked to make is neither challenged away nor routed past them. A reply on
# the ladder is matched alone, never read, checked or sorted again: the
# option a held answer names was checked on the first rung, and a moved
# answer goes to the operator either way.
#
# Fixed rounds come before the operator, sent by code rather than chosen
# (settled 2026-10-05: the operator does not wait the research out). An
# answer that moved on the ladder is sent the bigger look around first, so it
# arrives better researched, then "are you sure?" once more (settled
# 2026-10-06, the operator's own sequence); whatever the agent answers, the
# question still goes on. No fixed round asks the agent to rethink, so none
# counts toward the send-back limit, and each is sent at most once per
# question: their count is fixed, and the limit guards against a loop, which
# a fixed round cannot make. A gate failure gets none: the operator is told
# at once, and nothing more is asked of the agent.
#
# No round asks the agent to retell a question plainly before it reaches the
# operator (dropped 2026-10-07, the operator's call): the question as the
# agent asked it opens their message, and the summary's fixed parts, written
# by a fresh model in everyday words, are its plain version. So the message
# is made in the stop that decides the question is theirs, and nothing is
# held over to a later stop for it.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin and carries
# the reply as written, which is handed to the reader unread: the gate never
# reads the conversation itself, and decides from checked forms alone.
# Answering {"decision":"block","reason":…} keeps the agent working with the
# reason as its next instruction, and the stop that follows is marked
# stop_hook_active, which tells a reply to the gate from one to a new turn of
# the operator's. A systemMessage shows the operator its words whole and is
# never seen by the model. Printing nothing lets the reply stop as it is.
#
# Every question let go to the operator leaves one line in the question log,
# with what the gate knew of it, so it can be answered, counted and reopened
# later; a broken gate holding a question logs it too, marked with why. The
# log never holds a question up: where its line cannot be written, the
# operator is told so under the question.
#
# Fails toward the operator, never toward the agent: a part that will not
# load, an event, form, preset or record that cannot be read, a model call
# refused or out of time — every refusal ends this script, and the trap below
# lets the reply stop with a message naming why. A gate that held the reply
# on its own failure could hold the agent forever, unseen.
set -euo pipefail

# The file every part's refusal is gathered in, read by the trap below. No
# function may declare a local of this name: the trap runs inside whichever
# function called exit, and would read that local instead.
reasons=""

# Armed before anything is loaded, as the organizer's hooks are and for the
# same reason: a part that cannot be loaded ends bash with an ordinary error
# and no ERR trap run. Any way out but a clean finish lets the reply stop and
# tells the operator, with whatever the failing part said; where the words
# themselves could not be loaded, the message has its own.
answer_unjudged() {
  local status=$? why=""
  if [ -n "$reasons" ]; then
    why="$(cat "$reasons" 2>/dev/null || true)"
    rm -f "$reasons"
  fi
  [ "$status" -eq 0 ] && return
  # Nothing below may end the trap before the operator is answered.
  set +e
  if declare -F gate_broken_note >/dev/null && declare -F to_operator_answer >/dev/null; then
    local message logged
    message="$(gate_broken_note "$why")"
    if declare -F log_broken >/dev/null; then
      logged="$(log_broken "$message" 2>/dev/null)"
      [ -z "$logged" ] || message+=$'\n'"$logged"
    fi
    to_operator_answer "$message"
  else
    jq -cn --arg why "$why" \
      '{systemMessage: ("Stand-in: a part of the gate could not be loaded, so this reply was not judged.\n" + $why)}' 2>/dev/null \
      || printf '%s\n' '{"systemMessage":"Stand-in: a part of the gate could not be loaded, so this reply was not judged."}'
  fi
  exit 0
}
trap answer_unjudged EXIT

# Every part says why it refused on stderr; gathered here, it becomes the
# reason the operator is shown. Nothing written there reaches Claude Code,
# which shows a stopping hook's stderr only in its verbose mode.
reasons="$(mktemp)"
exec 2>"$reasons"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/stop-event.sh"
. "$tool_root/lib/switch.sh"

# Every value below is resolved into a variable before use, never inline as
# an argument: a failing command substitution inside an argument does not end
# the script, and the refusal would go unseen.
event="$(cat)"
event="$(refuse_unreadable_event "$event")"
session="$(to_event_session "$event")"
history="$(get_config_path AIDK_STAND_IN_HISTORY)"
switch="$(find_switch "$history" "$session")"
[ -n "$switch" ] || exit 0

# The rest of the gate is loaded only where the stand-in is on: this hook runs
# at the end of every reply in every session, and loading it all took most of
# its time where it then did nothing.
. "$tool_root/lib/record.sh"
. "$tool_root/lib/reader.sh"
. "$tool_root/lib/checker.sh"
. "$tool_root/lib/sorter.sh"
. "$tool_root/lib/step-go.sh"
. "$tool_root/lib/trial.sh"
. "$tool_root/lib/round.sh"
. "$tool_root/lib/challenge.sh"
. "$tool_root/lib/routes.sh"
. "$tool_root/lib/ladder.sh"
. "$tool_root/lib/matcher.sh"
. "$tool_root/lib/reading.sh"
. "$tool_root/lib/summary.sh"
. "$tool_root/lib/operator-message.sh"
. "$tool_root/lib/question-log.sh"
. "$tool_root/lib/briefs.sh"
. "$tool_root/lib/closing.sh"
. "$tool_root/lib/closing-reader.sh"
. "$tool_root/lib/changes.sh"
. "$tool_root/lib/end-report.sh"
. "$tool_root/lib/cases.sh"
. "$tool_root/lib/woken.sh"
. "$tool_root/lib/resume.sh"
. "$tool_root/lib/owed.sh"
. "$tool_root/lib/exam.sh"

preset="$(get_config_path AIDK_STAND_IN)"
rules="$(get_config_path AIDK_RULES)"
conventions="$(get_config_path AIDK_CONVENTIONS)"
reply="$(to_event_reply "$event")"
root="$(get_project_root)"
# The case-writer's command, as the agent is told to type it once a brief is
# finished: the entry by its whole path, since the agent runs it from
# wherever its shell stands.
cases_command="$tool_root/bin/stand-in.sh $CASES_COMMAND"
# The exam's command, as the agent is told to type it while an exam is owed,
# by its whole path for the same reason.
exam_command="$tool_root/bin/stand-in.sh $EXAM_COMMAND"
record_file="$(to_record_path "$history" "$session")"
saved="$(read_session_record "$record_file")"
record="$saved"
# A new turn of the operator's lets go of whatever question the gate held.
is_event_continuation "$event" || record="$(with_chain_reset "$record")"

# The record is put in place before any answer is printed, so no answer
# stands on a count or a challenge that was not kept; a session the gate
# never held anything for gets no file.
keep_record() {
  [ "$record" = "$saved" ] || write_session_record "$record_file" "$record"
}

let_stop() {
  record="$(with_chain_reset "$record")"
  keep_record
  exit 0
}

# The words of the preset's ladder message named. Every message the gate
# sends is asked for each time, so a preset missing any is refused on the
# first question it would be needed for, never half-way through one.
ladder_message() {
  local messages
  messages="$(get_ladder_messages "$preset" "${LADDER_MESSAGES[@]}")" || return 1
  jq -r --arg name "$1" '.[$name]' <<<"$messages"
}

# Hold the reply and send the agent the words given. The reply and the words
# join the question's exchange, which the summary is written from.
hold_reply() {
  record="$(with_turn "$record" "$EXCHANGE_AGENT" "$reply")"
  record="$(with_turn "$record" "$EXCHANGE_STAND_IN" "$1")"
  keep_record
  to_block_answer "$1"
  exit 0
}

# Send the question back to the agent with the words given, asking it to
# rethink, unless it has been sent back as often as it may be: then it goes
# to the operator, with what would have been sent.
send_back() {
  local words="$1" question="$2"
  if is_send_back_spent "$record"; then
    bring_operator "$question" "$(gate_loop_line "$SEND_BACK_LIMIT" "$words")"
  fi
  record="$(with_send_back "$record")"
  hold_reply "$words"
}

# Send the fixed round named: never counted toward the send-back limit, and
# refused rather than sent a second time for one question. A second sending
# would be the gate looping on its own rounds, which nothing else would stop.
send_round() {
  local name="$1" message words
  if is_round_sent "$record" "$name"; then
    refuse_round_twice_note "$name" >&2
    exit 1
  fi
  message="$(to_round_message_name "$name")"
  words="$(ladder_message "$message")"
  record="$(with_round "$record" "$name")"
  hold_reply "$(gate_challenge_note "$words")"
}

# The answers the question has had, as the operator would read them where the
# summary fails: the ladder's, or the question as last asked.
current_answers() {
  local ladder asked
  ladder="$(to_ladder "$record")"
  if [ -z "$ladder" ]; then
    asked="$(to_asked "$record")"
    [ -n "$asked" ] || return 0
    ladder="$(to_asked_ladder "$asked")"
  fi
  gate_answers_heading
  derive_answer_lines "$ladder"
}

# Bring the operator a question, given the question as asked, why it came to
# them, the label the stand-in would have approved (empty for none), the
# cold reading's part (empty where none ran), its own words (empty where
# none were written), and how many times the approved label held (empty
# where it would have stood with no challenge). Every route to the operator
# ends here, the loop guard's included, and the message is made, shown and
# logged in this stop: the reply that brought the question here joins the
# exchange as its last turn, and the summary is written from the whole of
# it. The summary never holds the question up: where it fails, the operator
# is told why and shown the answers as given.
bring_operator() {
  local question="$1" why="$2" approved="${3:-}" reading="${4:-}" reading_text="${5:-}" held="${6:-}"
  local answers parts exchange failure summary="" failed="" story message logged
  answers="$(current_answers)"
  parts="$(to_operator_message_parts "$question" "$approved" "$why" "$reading" "$answers" "$reading_text" "$held")"
  record="$(with_turn "$record" "$EXCHANGE_AGENT" "$reply")"
  exchange="$(to_exchange "$record")"
  failure="$(mktemp)"
  if ! summary="$(get_summary "$exchange" 2>"$failure")"; then
    summary=""
    failed="$(cat "$failure")"
  fi
  rm -f "$failure"
  story="$(to_operator_story "$parts" "$summary" "$failed")"
  message="$(to_operator_message "$parts" "$story")"
  logged="$(log_let_go "$parts" "$why" "$summary")"
  [ -z "$logged" ] || message+=$'\n'"$logged"
  record="$(with_chain_reset "$record")"
  keep_record
  to_operator_answer "$message"
  exit 0
}

# Settle a question without the operator, its kind through the trial, given
# the question as asked and the option settled on: logged as settled, so it
# is listed and can be reopened, and the agent told to go on with it. Never
# brought to the operator, so it is given no summary. A settling that cannot
# be logged is never given, since nobody could list or reopen it: the
# question goes to the operator instead, at once and as it stands, as a
# broken gate's does.
settle_question() {
  local question="$1" approved="$2" parts logged settled
  parts="$(to_operator_message_parts "$question" "$approved" "" "" "" "")"
  settled="$(jq -cn --arg outcome "$OUTCOME_SETTLED" '{outcome: $outcome}')"
  record="$(with_turn "$record" "$EXCHANGE_AGENT" "$reply")"
  logged="$(log_let_go "$parts" "" "" "$settled")"
  record="$(with_chain_reset "$record")"
  keep_record
  if [ -n "$logged" ]; then
    to_operator_answer "$(gate_operator_note "$question" "$(gate_settle_unlogged_line "$approved")"$'\n'"$logged")"
    exit 0
  fi
  to_block_answer "$(gate_settled_note "$approved")"
  exit 0
}

# Write the question the record holds to the log as it is let go, given the
# message's parts, why it came to the operator, one reason a line, the
# summary's parts as JSON (empty where it failed), kept as the operator was
# shown them, and for a step's report its kind, outcome and step as JSON
# (empty for a question). Prints nothing where the line was written, and
# otherwise the line telling the operator it was not, with why. The briefs
# the session holds are logged as unknown where the organizer cannot say,
# rather than the line lost: a project may run the stand-in with no briefs
# folder at all.
log_let_go() {
  local parts="$1" why_lines="$2" summary="$3" step="${4:-}" briefs id when details line why
  why="$(mktemp)"
  briefs="$(get_held_briefs "$session" 2>/dev/null)" || briefs=null
  id="$(mint_log_id)"
  when="$(get_log_now)"
  details="$(jq -cn --arg id "$id" --arg when "$when" --arg session "$session" --argjson briefs "$briefs" \
    --arg reasons "$why_lines" --argjson summary "${summary:-null}" \
    --argjson step "${step:-null}" \
    '{id: $id, when: $when, session: $session, briefs: $briefs, reasons: $reasons,
      summary: $summary} + ($step // {})')"
  if ! line="$(to_log_line "$record" "$parts" "$details" 2>"$why")" \
    || ! append_log_line "$(to_log_dir "$history")" "$line" 2>"$why"; then
    gate_log_failed_line "$(cat "$why")"
  fi
  rm -f "$why"
}

# A broken gate's question to the log, given the message the operator is
# shown, which is why it came to them: the question as last read. Nothing
# where the gate held no question: a reply it could not read may have asked
# nothing.
log_broken() {
  local message="$1" parts asked
  [ -n "${history:-}" ] && [ -n "${session:-}" ] && [ -n "${record:-}" ] || return 0
  asked="$(to_asked "$record")"
  [ -n "$asked" ] || return 0
  parts="$(jq -c '{question, approved: ""}' <<<"$asked")"
  log_let_go "$parts" "$message" ""
}

# Put a question on the ladder, or on the light check, as the route given
# says: its first rung is the form in hand, and the agent is sent its route's
# first challenge. The lines given are shown to the operator beside whatever
# the climb brings them.
start_ladder() {
  local form="$1" kind="$2" route="$3" lines="$4" question first ladder name words
  question="$(jq -r '.question' <<<"$form")"
  first="$(to_first_answer "$form")"
  record="$(with_ladder "$record" "$question" "$kind" "$route" "$lines" "$first")"
  ladder="$(to_ladder "$record")"
  name="$(to_rung_message_name "$ladder")"
  words="$(ladder_message "$name")"
  send_back "$(gate_challenge_note "$words")" "$question"
}

# An answer that held on every rung of its climb, the ladder's or the light
# check's. While its kind is on trial, which every kind is, it still comes to
# the operator, marked with what the stand-in would have approved and how
# many times it held, and is counted toward the trial; once switched, it is
# settled without them.
answer_held() {
  local ladder="$1" question recommended why held
  question="$(jq -r '.question' <<<"$ladder")"
  recommended="$(jq -r '.first.recommended' <<<"$ladder")"
  if is_on_trial "$(jq -r '.kind' <<<"$ladder")"; then
    why="$(to_held_why "$ladder")"
    held="$(to_ladder_rungs "$ladder")"
    bring_operator "$question" "$why" "$recommended" "" "" "$held"
  fi
  settle_question "$question" "$recommended"
}

# An answer that moved under the light check's one challenge: to the
# operator, told it did not hold. No bigger look around and no cold reading,
# which are the ladder's: a name inside the code is cheap to change, and the
# operator answers it at a glance (settled 2026-10-06).
answer_light_moved() {
  local ladder="$1" question why
  question="$(jq -r '.question' <<<"$ladder")"
  why="$(to_changed_why "$ladder")"
  bring_operator "$question" "$why"
}

# A question whose kind's recommendation stands with no challenge, given the
# reader's form, the kind's entry and any lines the operator would be shown
# beside it. While the kind is on trial, which every kind is, it comes to the
# operator, marked with what the stand-in would have accepted, and is counted
# toward the trial; once switched, it is settled without them.
answer_accepted() {
  local form="$1" entry="$2" lines="$3" question recommended name why
  question="$(jq -r '.question' <<<"$form")"
  recommended="$(jq -r '.recommended' <<<"$form")"
  name="$(jq -r '.name' <<<"$entry")"
  if is_on_trial "$name"; then
    why="$(gate_trial_line "$name")"$'\n'"$lines"
    bring_operator "$question" "$why" "$recommended"
  fi
  settle_question "$question" "$recommended"
}

# An answer that moved on the rungs: the bigger look around, once. Whatever
# its reply says, "are you sure?" follows it once more, and the question then
# goes to the operator: an answer that moved is already unsure.
answer_changed() {
  send_round "$LADDER_BIGGER_LOOK"
}

# An answer that moved, then moved again after the bigger look around when
# asked once more whether it was sure: a cold second reading, run here and
# only here, and to the operator. Run by the stand-in itself, never asked of
# the agent: the agent would read it with its own proposal in view, could
# lead it, and code could not tell whether it ran. The reading runs in this
# stop, the one that knows the answer moved again, before the summary that
# brings the question to the operator: the hook's time limit is sized for
# the three together. It never holds the question up: where it fails or runs
# out of time, the operator is told why there is none.
answer_moved_again() {
  local ladder="$1" question options why reading part
  question="$(jq -r '.question' <<<"$ladder")"
  options="$(jq -c '.first.options' <<<"$ladder")"
  why="$(mktemp)"
  if reading="$(get_cold_reading "$question" "$options" "$rules" "$conventions" "$history" 2>"$why")"; then
    part="$(gate_reading_note "$reading")"
  else
    reading=""
    part="$(gate_reading_failed_line "$(cat "$why")")"
  fi
  rm -f "$why"
  why="$(to_changed_why "$ladder")"
  bring_operator "$question" "$why" "" "$part" "$reading"
}

# An answer that moved, then held after the bigger look around when asked
# once more whether it was sure: no cold reading, and to the operator, told it
# moved and then held. Never the would-have-approved mark: an answer that
# moved once was unsure, and must not earn silence when its kind leaves the
# trial.
answer_looked_held() {
  local ladder="$1" question why
  question="$(jq -r '.question' <<<"$ladder")"
  why="$(to_looked_held_why "$ladder")"
  bring_operator "$question" "$why"
}

# The matcher's pick of this reply against the ladder's first list, kept on
# the ladder; the ladder as it then stands is left in the variable ladder.
match_reply() {
  local question options pick
  question="$(jq -r '.question' <<<"$ladder")"
  options="$(jq -c '.first.options' <<<"$ladder")"
  pick="$(get_matcher_answer "$question" "$options" "$reply")"
  record="$(with_ladder_pick "$record" "$pick")"
  ladder="$(to_ladder "$record")"
}

# The reply to a rung: matched and kept, then the next rung's challenge sent,
# or the ladder's outcome taken on.
climb_ladder() {
  local question step name words
  match_reply
  question="$(jq -r '.question' <<<"$ladder")"
  step="$(derive_ladder_step "$ladder")"
  case "$step" in
    "$LADDER_CLIMB")
      name="$(to_rung_message_name "$ladder")"
      words="$(ladder_message "$name")"
      send_back "$(gate_challenge_note "$words")" "$question"
      ;;
    "$LADDER_HELD") answer_held "$ladder" ;;
    *)
      if [ "$(jq -r '.route' <<<"$ladder")" = "$ROUTE_LIGHT" ]; then
        answer_light_moved "$ladder"
      fi
      answer_changed
      ;;
  esac
}

# The reply to the bigger look around: matched like a rung, its answer kept
# beside the others, and "are you sure?" sent once more whatever it says.
answer_looked() {
  match_reply
  send_round "$LADDER_SURE_AGAIN"
}

# The reply to "are you sure?" asked once more: matched like a rung, and
# compared in code with the answer to the bigger look around.
answer_sure_again() {
  match_reply
  if is_look_held "$ladder"; then
    answer_looked_held "$ladder"
  else
    answer_moved_again "$ladder"
  fi
}

# Write a step's report to the log as it is let go, given the reader's form,
# the sorter's labelling, the go kind's entry, the decision put to the
# operator, the go the stand-in would give or gave (empty for none), why it
# came to them, one reason a line, and how it ended. The report joins the
# exchange first, as the last reply. Prints what log_let_go prints.
log_step() {
  local form="$1" sort="$2" entry="$3" question="$4" approved="$5" why="$6" outcome="$7" parts step
  parts="$(to_operator_message_parts "$question" "$approved" "$why" "" "")"
  step="$(jq -cn --arg kind "$(jq -r '.name' <<<"$entry")" --arg outcome "$outcome" \
    --argjson step "$(to_step_details "$form" "$sort")" '{kind: $kind, outcome: $outcome, step: $step}')"
  record="$(with_turn "$record" "$EXCHANGE_AGENT" "$reply")"
  log_let_go "$parts" "$why" "" "$step"
}

# Let the reply stop, showing the operator the message given and, under it,
# any line the log gave back.
let_stop_told() {
  local message="$1" logged="$2"
  [ -z "$logged" ] || message+=$'\n'"$logged"
  record="$(with_chain_reset "$record")"
  keep_record
  to_operator_answer "$message"
  exit 0
}

# A step's report the go is the operator's for, given the reader's form, the
# sorter's labelling, the go kind's entry, and why, one reason a line. The
# report itself is already in front of them as the agent wrote it, so it is
# given no summary: a step's report is not a question, and the note beside it
# says only why the go is theirs.
step_to_operator() {
  local form="$1" sort="$2" entry="$3" why="$4" question logged
  question="$(to_step_question "$form")"
  logged="$(log_step "$form" "$sort" "$entry" "$question" "" "$why" "$OUTCOME_TO_OPERATOR")"
  let_stop_told "$(gate_step_operator_note "$question" "$why")" "$logged"
}

# Send a step's report back to the agent with the words given, to fix what is
# left before the next step, unless it has been sent back as often as it may
# be: then it goes to the operator, with what would have been sent. The
# agent's next reply is read again like any other, a new report included.
send_step_back() {
  local words="$1" form="$2" sort="$3" entry="$4"
  if is_send_back_spent "$record"; then
    step_to_operator "$form" "$sort" "$entry" "$(gate_loop_line "$SEND_BACK_LIMIT" "$words")"
  fi
  record="$(with_send_back "$record")"
  hold_reply "$words"
}

# A step's report the stand-in would say go to. While its kind is on trial,
# which every kind is, the reply stops with the note that it would have said
# go and what was fixed in passing, and the go is logged as it would have
# been approved, so it is counted toward the trial. Once the kind is
# switched, the agent is told to go on and the go is logged as settled, so it
# is listed and can be reopened; a go that cannot be logged is never given,
# since nobody could list or reopen it, and goes to the operator instead.
answer_go() {
  local form="$1" sort="$2" entry="$3" question fixed why logged
  question="$(to_step_question "$form")"
  fixed="$(derive_fixed_lines "$form")"
  if is_on_trial "$(jq -r '.name' <<<"$entry")"; then
    why="$(gate_trial_line "$(jq -r '.name' <<<"$entry")")"
    logged="$(log_step "$form" "$sort" "$entry" "$question" "$(step_go_words)" "$why" "$OUTCOME_WOULD_HAVE_APPROVED")"
    let_stop_told "$(to_go_message "$question" "$why" "$fixed")" "$logged"
  fi
  logged="$(log_step "$form" "$sort" "$entry" "$question" "$(step_go_words)" "" "$OUTCOME_SETTLED")"
  if [ -n "$logged" ]; then
    let_stop_told "$(to_go_message "$question" "$logged" "$fixed")" ""
  fi
  record="$(with_chain_reset "$record")"
  keep_record
  to_block_answer "$(gate_go_note)"
  exit 0
}

# A finished step's report that asks the operator nothing: its problems
# labelled by the sorter, then the go said, the agent sent back, or the report
# brought to the operator, as the forms decide. A preset with no kind for the
# step go lets the report stop as it is.
answer_step() {
  local form="$1" entry sort reopened briefs labels step words
  entry="$(find_go_kind "$preset")"
  [ -n "$entry" ] || let_stop
  sort="$(get_step_sort "$form" "$reply" "$preset")"
  # While a decision the operator reopened waits to be asked again, the go is
  # theirs: a reopened go is asked again as whether to go on, which reads as a
  # step's report, and must not be given silently a second time. The mark is
  # kept, for the question it waits for.
  reopened="$(to_reopened "$record")"
  [ -z "$reopened" ] || step_to_operator "$form" "$sort" "$entry" "$(gate_reopened_step_line "$reopened")"
  briefs="$(get_held_briefs "$session" 2>/dev/null)" || briefs=null
  labels="$(list_risks "$preset")"
  labels="$(list_major_labels "$labels")"
  step="$(derive_step_go "$form" "$sort" "$briefs" "$labels")"
  words="$(jq -r '.words' <<<"$step")"
  case "$(jq -r '.next' <<<"$step")" in
    "$STEP_NEXT_AGENT") send_step_back "$words" "$form" "$sort" "$entry" ;;
    "$STEP_NEXT_OPERATOR") step_to_operator "$form" "$sort" "$entry" "$words" ;;
    "$STEP_NEXT_GO") answer_go "$form" "$sort" "$entry" ;;
  esac
}

# A reply that closes the round of questions and asks to start building: a
# request that is always the operator's, brought to them with every decision
# of the round laid out, numbered and saying who decided it (settled
# 2026-10-06). The request is in front of them as the agent wrote it, so it is
# given no summary, as a step's report is not. Its line in the log is
# where the session's next round begins, and the operator's answer — "go", or
# "reopen" and a number — is kept on it. The round reader never holds the
# request up: where it fails, each decision is shown as the log keeps it,
# saying why.
answer_round() {
  local lines decisions answer="" failed="" why shown message parts details logged
  lines="$(list_log_lines "$(to_log_dir "$history")")"
  decisions="$(derive_round_decisions "$lines" "$session")"
  if [ "$(jq 'length' <<<"$decisions")" -gt 0 ]; then
    why="$(mktemp)"
    if ! answer="$(get_round_answer "$decisions" 2>"$why")"; then
      answer=""
      failed="$(cat "$why")"
    fi
    rm -f "$why"
  fi
  shown="$(to_round_shown "$decisions" "$answer")"
  message="$(format_round_message "$shown" "$failed")"
  why="$(gate_round_why_line)"
  parts="$(to_operator_message_parts "$(gate_round_question)" "" "$why" "" "")"
  details="$(jq -cn --arg outcome "$OUTCOME_TO_OPERATOR" --argjson round "$shown" '{outcome: $outcome, round: $round}')"
  record="$(with_turn "$record" "$EXCHANGE_AGENT" "$reply")"
  logged="$(log_let_go "$parts" "$why" "" "$details")"
  [ -z "$logged" ] || message+=$'\n'"$logged"
  record="$(with_chain_reset "$record")"
  keep_record
  to_operator_answer "$message"
  exit 0
}

# The words of the preset's closing-loop message named, every one asked for
# each time, as the ladder's are.
closing_message() {
  local messages
  messages="$(get_closing_messages "$preset" "${CLOSING_MESSAGES[@]}")" || return 1
  jq -r --arg name "$1" '.[$name]' <<<"$messages"
}

# Send the look named, with how to report what it finds, its reply awaited as
# a fixed round's is: never counted toward the send-back limit, and refused
# rather than sent twice in one round.
send_look() {
  local name="$1" words
  if is_round_sent "$record" "$name"; then
    refuse_round_twice_note "$name" >&2
    exit 1
  fi
  words="$(closing_message "$name")"
  record="$(with_round "$record" "$name")"
  hold_reply "$(gate_challenge_note "$words"; to_closing_report_note)"
}

# A reply saying the work is done: the closing loop's first look, for the
# briefs the session holds. A session holding none has nothing to sweep for,
# and stops as it would without the loop; where which it holds cannot be
# told, the operator is told the loop was not started, rather than the claim
# passing as if it had been swept.
start_closing() {
  local why briefs failed
  why="$(mktemp)"
  if ! briefs="$(get_held_briefs "$session" 2>"$why")"; then
    failed="$(cat "$why")"
    rm -f "$why"
    let_stop_told "$(closing_briefs_unknown_note "$failed")" ""
  fi
  rm -f "$why"
  [ "$(jq 'length' <<<"$briefs")" -gt 0 ] || let_stop
  record="$(with_closing "$record" "$briefs")"
  send_look "$CLOSING_CLEANUP_LOOK"
}

# A step's report naming no next step and not saying the brief is done: asked
# whether the whole brief is done, once, instead of the report passing on
# (settled 2026-10-06). The reader is never asked whether work sounds
# finished: what it reads off the agent's own answer decides, so a reply
# saying it is done starts the loop, and one naming a next step is weighed
# for the go.
ask_whole_done() {
  local words
  words="$(closing_message "$CLOSING_WHOLE_DONE")"
  record="$(with_round_sent "$record" "$CLOSING_WHOLE_DONE")"
  hold_reply "$(gate_challenge_note "$words")"
}

# True if the step's report given waits on whether the whole brief is done:
# it names no next step, the question was not asked yet, and the session
# holds a brief to be done with. Asked once: a second report naming no next
# step is weighed as any step's, and reaches the operator saying so.
is_whole_done_unasked() {
  local briefs
  [ -z "$(jq -r '.next_step' <<<"$1")" ] || return 1
  ! is_round_sent "$record" "$CLOSING_WHOLE_DONE" || return 1
  briefs="$(get_held_briefs "$session" 2>/dev/null)" || return 1
  [ "$(jq 'length' <<<"$briefs")" -gt 0 ]
}

# The checks code makes of each finding the agent would fix in passing, left
# in the variable checks, keyed by its place in the form: which briefs other
# sessions hold where its files lie, asked of the organizer, and whether its
# files hold changes nobody committed, asked of git. Either one that cannot
# answer ends the gate: a fix in passing nobody could check is never let
# through.
check_findings() {
  local form="$1" quick index files held uncommitted
  checks="{}"
  while IFS= read -r quick; do
    index="$(jq -r '.index' <<<"$quick")"
    readarray -t files < <(jq -r '.files[]' <<<"$quick")
    held="$(list_taken_briefs "${files[@]}")"
    held="$(to_other_briefs "$held" "$session")"
    uncommitted="$(list_uncommitted_paths "$root" "${files[@]}")"
    checks="$(with_finding_check "$checks" "$index" "$(to_finding_check "$held" "$uncommitted")")"
  done < <(jq -c '.[]' <<<"$(to_quick_files "$form")")
}

# Write a closing round to the log, given the decision it put, why it came to
# the operator (empty where it did not), how it ended, and its details as
# to_closing_details gives them. Prints what log_let_go prints.
log_round() {
  local question="$1" why="$2" outcome="$3" closing="$4" parts details
  parts="$(to_operator_message_parts "$question" "" "$why" "" "")"
  details="$(jq -cn --arg outcome "$outcome" --argjson closing "$closing" '{outcome: $outcome, closing: $closing}')"
  log_let_go "$parts" "$why" "" "$details"
}

# Both looks are in: the round is logged, one line with every finding and
# its sort, and what follows is decided from the sorts. Nothing belonging
# here ends the loop: the briefs are finished. Something belonging here goes
# back to the agent to be asked as questions; on the round that makes it the
# notice's count, to the operator instead, with the list. A round that cannot
# be logged goes to the operator too: its count could not be kept, and the
# notice could then never come.
finish_round() {
  local closing briefs findings lines tally number counted question details why message logged
  closing="$(to_closing "$record")"
  briefs="$(jq -c '.briefs' <<<"$closing")"
  findings="$(jq -c '.findings' <<<"$closing")"
  lines="$(list_log_lines "$(to_log_dir "$history")")"
  tally="$(derive_closing_tally "$lines" "$session" "$briefs" "$findings")"
  number="$(jq -r '.number' <<<"$tally")"
  counted="$(jq -r '.counted' <<<"$tally")"
  question="$(closing_round_question "$number")"
  details="$(to_closing_details "$number" "$briefs" "$findings")"
  record="$(with_turn "$record" "$EXCHANGE_AGENT" "$reply")"
  if is_closing_here "$findings" && [ "$counted" -ge "$CLOSING_NOTICE_ROUNDS" ]; then
    why="$(closing_notice_why_line "$counted")"
    logged="$(log_round "$question" "$why" "$OUTCOME_TO_OPERATOR" "$details")"
    let_stop_told "$(closing_notice_note "$counted"; format_closing_findings "$findings")" "$logged"
  fi
  logged="$(log_round "$question" "" "$OUTCOME_TO_AGENT" "$details")"
  if [ -n "$logged" ]; then
    let_stop_told "$(closing_unlogged_note "$number"; format_closing_findings "$findings")" "$logged"
  fi
  is_closing_here "$findings" || finish_briefs "$briefs" "$findings"
  message="$(format_closing_agent_note "$findings" "" "$cases_command")"
  record="$(with_chain_reset "$record")"
  keep_record
  to_block_answer "$message"
  exit 0
}

# A round that came back with nothing belonging here: the briefs swept for
# are finished through the work organizer's done, run here rather than left
# to the agent (settled 2026-10-05: finishing is done, run in this routine),
# so the end report shows what finishing freed as the organizer printed it,
# from its one source. The agent is then told to commit exactly that, run
# the full check and say how it went, and its reply brings the end report. A
# done that refuses lets the reply stop with the operator told why, what was
# changed before it and the round's findings: nobody is told to commit a
# finish half made.
finish_briefs() {
  local briefs="$1" findings="$2" brief why printed finished="" failed message
  why="$(mktemp)"
  while IFS= read -r brief; do
    # The trailing "x" keeps the last newline of what the organizer printed,
    # which a command substitution would strip; it is printed only where
    # done finished.
    if ! printed="$(finish_brief "$brief" 2>"$why" && printf x)"; then
      failed="$(cat "$why")"
      rm -f "$why"
      let_stop_told "$(format_finish_failed "$failed" "$finished" "$findings")" ""
    fi
    finished+="${printed%x}"
  done < <(jq -r '.[]' <<<"$briefs")
  rm -f "$why"
  message="$(format_closing_agent_note "$findings" "$finished" "$cases_command")"
  record="$(with_closing_finished "$record" "$finished")"
  record="$(with_round "$record" "$CLOSING_FINISHED")"
  keep_record
  to_block_answer "$message"
  exit 0
}

# The reply after the briefs were finished: the end report, whatever the reply
# says, made from the question log and what finishing printed. The reply is
# read by the reader for whether the full check passed, and for nothing else;
# where it cannot be read, the report still comes, saying why that is not
# known. A reply that also asks something stands above the report as written:
# the brief is finished, and nothing is left for the gate to hold.
answer_finished() {
  local closing why form="" failed="" lines report
  closing="$(to_closing "$record")"
  [ -n "$closing" ] || { refuse_state_unreadable_note "$record_file" >&2; exit 1; }
  why="$(mktemp)"
  if ! form="$(get_reader_form "$reply" 2>"$why")"; then
    form=""
    failed="$(cat "$why")"
  fi
  rm -f "$why"
  lines="$(list_log_lines "$(to_log_dir "$history")")"
  report="$(format_end_report "$lines" "$closing" "$form" "$failed")"
  record="$(with_chain_reset "$record")"
  keep_record
  to_operator_answer "$report"
  exit 0
}

# The reply to a look, whatever it says: read by the closing reader alone,
# each finding the agent would fix in passing checked, and kept on the round;
# then the second look, or, after it, the round's end.
answer_look() {
  local look="$1" closing taken others form findings
  closing="$(to_closing "$record")"
  [ -n "$closing" ] || { refuse_state_unreadable_note "$record_file" >&2; exit 1; }
  taken="$(list_taken_briefs)"
  others="$(to_other_briefs "$taken" "$session")"
  form="$(get_look_form "$reply" "$others" "$root")"
  check_findings "$form"
  findings="$(to_checked_findings "$form" "$look" "$checks")"
  record="$(with_closing_findings "$record" "$findings")"
  [ "$look" != "$CLOSING_CLEANUP_LOOK" ] || send_look "$CLOSING_USE_LOOK"
  finish_round
}

# A proposal the agent dropped under its kind's challenge: a line of its own
# in the question log, outcome dropped, with the options it offered, so the
# end report lists it and the operator can reopen it (settled 2026-10-06: the
# session's record, its only home before, goes with the session). The
# question is then let go. A drop that cannot be logged lets the reply stop
# with the operator told: nobody could list or reopen it, and they would
# never learn the agent let it go.
drop_proposal() {
  local form="$1" question parts dropped details logged
  question="$(jq -r '.question' <<<"$form")"
  parts="$(to_operator_message_parts "$question" "" "" "" "")"
  dropped="$(to_first_answer "$form")"
  details="$(jq -cn --arg outcome "$OUTCOME_DROPPED" --argjson dropped "$dropped" \
    '{outcome: $outcome, dropped: $dropped}')"
  record="$(with_turn "$record" "$EXCHANGE_AGENT" "$reply")"
  logged="$(log_let_go "$parts" "" "" "$details")"
  [ -z "$logged" ] || let_stop_told "$(gate_drop_unlogged_note "$question")" "$logged"
  record="$(with_chain_reset "$record")"
}

# A question asked while a decision the operator reopened waits: theirs,
# whatever its kind and route, and the first mark taken off as it goes to
# them (settled 2026-10-06). The question is taken for the first reopened,
# whatever it asks: whether it is that decision would be a model's guess.
bring_reopened() {
  local question="$1" number="$2"
  record="$(without_first_reopened "$record")"
  bring_operator "$question" "$(gate_reopened_line "$number")"
}

# Take the route the question's forms decide.
route_question() {
  local form="$1" sort="$2" entry="$3" kept="$4" risks route words question name
  question="$(jq -r '.question' <<<"$form")"
  name="$(jq -r '.name' <<<"$entry")"
  risks="$(list_risks "$preset")"
  route="$(derive_route "$form" "$sort" "$entry" "$risks" "$kept")"
  words="$(jq -r '.words' <<<"$route")"
  case "$(jq -r '.route' <<<"$route")" in
    agent) send_back "$words" "$question" ;;
    operator) bring_operator "$question" "$words" ;;
    "$ROUTE_LADDER") start_ladder "$form" "$name" "$ROUTE_LADDER" "$words" ;;
    "$ROUTE_LIGHT") start_ladder "$form" "$name" "$ROUTE_LIGHT" "$words" ;;
    "$ROUTE_ACCEPT") answer_accepted "$form" "$entry" "$words" ;;
    # A route no case takes would let the reply stop unjudged and unseen, so
    # it is refused, which brings the reply to the operator with why.
    *)
      refuse_kind_route_note "$name" "$(jq -r '.route' <<<"$route")" "$(to_routes_line)" >&2
      exit 1
      ;;
  esac
}

# The ladder a round after the rungs answers, left in the variable ladder. A
# record awaiting such a round with no ladder is one the gate did not write.
take_ladder() {
  ladder="$(to_ladder "$record")"
  [ -n "$ladder" ] || { refuse_state_unreadable_note "$record_file" >&2; exit 1; }
}

# A step's report or a "brief done" from a session that edited what the
# stand-in judges by, given its exam owed: sent back to run the exam first
# (settled 2026-10-06, decision 7: until the exam passes, the gate sends that
# session's step reports and its "brief done" back), since a go given, or a
# brief finished, on a stand-in nobody re-examined could rest on judgement
# that drifted. Counted toward the send-back limit, so an exam that keeps
# failing reaches the operator rather than holding the agent forever.
answer_exam_owed() {
  local files
  files="$(format_owed_files "$1")"
  if is_send_back_spent "$record"; then
    let_stop_told "$(gate_exam_owed_operator_note "$SEND_BACK_LIMIT" "$exam_command" "$files")" ""
  fi
  record="$(with_send_back "$record")"
  hold_reply "$(gate_exam_owed_note "$exam_command" "$files")"
}

# The words of the preset's resume look-around named, every one asked for
# each time, as the ladder's are.
resume_message() {
  local messages
  messages="$(get_resume_messages "$preset" "${RESUME_MESSAGES[@]}")" || return 1
  jq -r --arg name "$1" '.[$name]' <<<"$messages"
}

# A session whose wait ended, given the wait's mark: sent the preset's look
# around, its record marked with the wait it woke from, so its report reaches
# the operator; or, where the wait could not be watched, the reply stops with
# the operator told why, which needs no word of the preset. The mark is
# removed before anything is sent, so one wait wakes the session once; the
# look around's words are read before that, so a preset missing them leaves
# the mark for the next stop and tells the operator.
answer_woken() {
  local mark="$1" words
  if ! is_wait_over "$mark"; then
    remove_woken_mark "$history" "$session"
    let_stop_told "$(format_wait_refused_note "$mark")" ""
  fi
  words="$(resume_message "$RESUME_LOOK_AROUND")"
  remove_woken_mark "$history" "$session"
  record="$(with_resumed "$record" "$mark")"
  hold_reply "$(format_resume_note "$words" "$mark")"
}

# A reply asking the operator nothing, from a session woken from a wait: its
# report, given the wait the record keeps, brought to the operator, whose go
# it waits for. Never weighed for a step's go, never the closing loop's start,
# never passed on silently: what the agent decided before the wait may no
# longer hold, and the operator says whether work resumes (settled
# 2026-10-06).
answer_resumed() {
  record="$(without_resumed "$record")"
  let_stop_told "$(format_resumed_note "$1")" ""
}

# A wait that ended is acted on at the first stop where the gate holds
# nothing for the session: a question in flight already has its way to the
# operator, and finishes first. The mark waits for that stop, read before the
# reply is, so the look around costs no model: the reply it holds is the
# agent's waking, which the report replaces. Called from an if's body, never
# after a || or &&, where bash would let a refusal inside it pass unseen.
if is_record_idle "$record"; then
  woken="$(find_woken_mark "$history" "$session")"
  if [ -n "$woken" ]; then answer_woken "$woken"; fi
fi

# A fixed round awaiting its reply takes this reply, whatever it says. A
# round the gate does not know is a record it did not write.
round="$(to_round "$record")"
case "$round" in
  "") ;;
  "$LADDER_BIGGER_LOOK") take_ladder; answer_looked ;;
  "$LADDER_SURE_AGAIN") take_ladder; answer_sure_again ;;
  "$CLOSING_CLEANUP_LOOK" | "$CLOSING_USE_LOOK") answer_look "$round" ;;
  "$CLOSING_FINISHED") answer_finished ;;
  *)
    refuse_state_unreadable_note "$record_file" >&2
    exit 1
    ;;
esac

# A question on the ladder takes this reply as its next rung, whatever it
# says: a reply that no longer asks the question is an answer that moved.
ladder="$(to_ladder "$record")"
[ -z "$ladder" ] || climb_ladder

form="$(get_reader_form "$reply")"

challenge="$(to_challenge "$record")"
if [ -n "$challenge" ]; then
  step="$(derive_challenge_step "$challenge" "$form")"
  challenged="$(jq -c '.form' <<<"$challenge")"
  question="$(jq -r '.question' <<<"$challenged")"
  words="$(jq -r '.words' <<<"$step")"
  case "$(jq -r '.next' <<<"$step")" in
    # Dropped: logged, and the reply is read on as any other, since it may
    # go on to ask something else.
    drop) drop_proposal "$challenged" ;;
    challenge)
      record="$(with_challenge_step "$record" 2)"
      send_back "$(gate_challenge_note "$words")" "$question"
      ;;
    routes)
      route_question "$challenged" "$(jq -c '.sort' <<<"$challenge")" "$(jq -c '.entry' <<<"$challenge")" true
      ;;
    *) bring_operator "$question" "$(gate_unanswered_line "$words")" ;;
  esac
fi

# A reply asking nothing stops as it is, unless it closes the round of
# questions and asks to start building, which reaches the operator with the
# round laid out; says the work is done, which starts the closing loop; or
# reports a step finished, which waits for a go the step go weighs, or, naming
# no next step, is asked whether the whole brief is done. A reply still asking
# a question is taken as a question first, even where it also asks to go on
# or says it is done: nothing is ready to go on, or done, while it is open.
# A claim of done is taken before a step's report it ends with: the loop is
# what decides done, so the claim is swept rather than weighed as a step. A
# session woken from a wait is the exception before all of these: whatever it
# reports reaches the operator for the go. A session owing the exam is sent
# back to run it before a claim of done or a step's report is weighed, the
# question whether the whole brief is done included, which is on the way to
# done; the mark is read only there, so no other stop pays for it.
if ! jq -e '.asks_operator' >/dev/null <<<"$form"; then
  resumed="$(to_resumed "$record")"
  if [ -n "$resumed" ]; then answer_resumed "$resumed"; fi
  if jq -e '.closes_round' >/dev/null <<<"$form"; then answer_round; fi
  if jq -e '.claims_done or .ends_step' >/dev/null <<<"$form"; then
    owed="$(find_owed_mark "$history" "$session")"
    if [ -n "$owed" ]; then answer_exam_owed "$owed"; fi
  fi
  if jq -e '.claims_done' >/dev/null <<<"$form"; then start_closing; fi
  if jq -e '.ends_step' >/dev/null <<<"$form"; then
    if is_whole_done_unasked "$form"; then ask_whole_done; fi
    answer_step "$form"
  fi
  let_stop
fi
question="$(jq -r '.question' <<<"$form")"
record="$(with_asked "$record" "$form")"

entries="$(list_check_entries "$rules" "$conventions")"
checked="$(get_checker_answer "$form" "$reply" "$entries")"
record="$(with_check "$record" "$checked")"
sendback="$(derive_checker_sendback "$checked" "$entries")"
[ -z "$sendback" ] || send_back "$sendback" "$question"

sort="$(get_sorter_answer "$form" "$reply" "$preset")"
record="$(with_sort "$record" "$sort")"
entry="$(get_kind_entry "$preset" "$(jq -r '.kind' <<<"$sort")")"
reopened="$(to_reopened "$record")"
[ -z "$reopened" ] || bring_reopened "$question" "$reopened"
first="$(jq -r '.challenge' <<<"$entry")"
if [ -n "$first" ]; then
  record="$(with_challenge "$record" "$entry" 1 "$form" "$sort")"
  send_back "$(gate_challenge_note "$first")" "$question"
fi

route_question "$form" "$sort" "$entry" false
