#!/usr/bin/env bash
# Claude Code Stop hook — the stand-in's gate, a thin orchestrator: at the end
# of every reply in a session the stand-in is switched on for, the reply is
# read into a form; a question to the operator is checked against the
# project's rules and conventions, sorted, challenged where its kind carries
# a challenge, and routed — back to the agent, on to the operator, or up the
# challenge ladder. A reply that reports a step finished and asks nothing is
# weighed for the operator's go to the next step: the go said, the agent sent
# back to fix what is left, or the report brought to the operator with why.
# In every other session it does nothing at all.
#
# The order is the point: the rules and conventions check runs before any
# route, so a question that breaks one never reaches the operator; the
# challenge runs before the routes, so a proposal the agent drops is never
# asked about. A reply on the ladder is matched alone, never read, checked or
# sorted again: the option a held answer names was checked on the first rung,
# and a moved answer goes to the operator either way.
#
# Fixed rounds come before the operator, sent by code rather than chosen
# (settled 2026-10-05: the operator does not wait the research out, and reads
# every question plainly worded). An answer that moved on the ladder is sent
# the bigger look around first, so it arrives better researched, then "are
# you sure?" once more (settled 2026-10-06, the operator's own sequence);
# whatever the agent answers, the question still goes on. Then every question
# bound for the operator, whatever its route, is sent the plain retelling,
# and the agent's rewrite is what the operator reads first: the agent knows
# the subject, and is the one to say it plainly. No fixed round asks the
# agent to rethink, so none counts toward the send-back limit, and each is
# sent at most once per question: their count is fixed, and the limit guards
# against a loop, which a fixed round cannot make. A gate failure gets none:
# the operator is told at once, and nothing more is asked of the agent.
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
. "$tool_root/lib/record.sh"
. "$tool_root/lib/reader.sh"
. "$tool_root/lib/checker.sh"
. "$tool_root/lib/sorter.sh"
. "$tool_root/lib/step-go.sh"
. "$tool_root/lib/challenge.sh"
. "$tool_root/lib/routes.sh"
. "$tool_root/lib/ladder.sh"
. "$tool_root/lib/matcher.sh"
. "$tool_root/lib/reading.sh"
. "$tool_root/lib/summary.sh"
. "$tool_root/lib/operator-message.sh"
. "$tool_root/lib/question-log.sh"
. "$tool_root/lib/briefs.sh"

# Every value below is resolved into a variable before use, never inline as
# an argument: a failing command substitution inside an argument does not end
# the script, and the refusal would go unseen.
event="$(cat)"
event="$(refuse_unreadable_event "$event")"
session="$(to_event_session "$event")"
history="$(get_config_path AIDK_STAND_IN_HISTORY)"
switch="$(find_switch "$history" "$session")"
[ -n "$switch" ] || exit 0

preset="$(get_config_path AIDK_STAND_IN)"
rules="$(get_config_path AIDK_RULES)"
conventions="$(get_config_path AIDK_CONVENTIONS)"
reply="$(to_event_reply "$event")"
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
# cold reading's part (empty where none ran) and its own words (empty where
# none were written). Every route to the operator
# ends here, the loop guard's included: the message is kept in parts and the
# agent is sent the plain retelling, whose reply finishes it.
bring_operator() {
  local question="$1" why="$2" approved="${3:-}" reading="${4:-}" reading_text="${5:-}" answers parts
  answers="$(current_answers)"
  parts="$(to_operator_message_parts "$question" "$approved" "$why" "$reading" "$answers" "$reading_text")"
  record="$(with_operator "$record" "$parts")"
  send_round "$LADDER_PLAIN_RETELLING"
}

# Write the question the record holds to the log as it is let go, given the
# message's parts, the question as retold (empty where it could not be read),
# why it came to the operator, one reason a line, the summary's parts as JSON
# (empty where it failed), kept as the operator was shown them, and for a
# step's report its kind, outcome and step as JSON (empty for a question).
# Prints nothing where the line was written, and otherwise the line telling
# the operator it was not, with why. The briefs the session holds
# are logged as unknown where the organizer cannot say, rather than the line
# lost: a project may run the stand-in with no briefs folder at all.
log_let_go() {
  local parts="$1" retold="$2" why_lines="$3" summary="$4" step="${5:-}" briefs id when details line why
  why="$(mktemp)"
  briefs="$(get_held_briefs "$session" 2>/dev/null)" || briefs=null
  id="$(mint_log_id)"
  when="$(get_log_now)"
  details="$(jq -cn --arg id "$id" --arg when "$when" --arg session "$session" --argjson briefs "$briefs" \
    --arg retold "$retold" --arg reasons "$why_lines" --argjson summary "${summary:-null}" \
    --argjson step "${step:-null}" \
    '{id: $id, when: $when, session: $session, briefs: $briefs, retold: $retold, reasons: $reasons,
      summary: $summary} + ($step // {})')"
  if ! line="$(to_log_line "$record" "$parts" "$details" 2>"$why")" \
    || ! append_log_line "$(to_log_dir "$history")" "$line" 2>"$why"; then
    gate_log_failed_line "$(cat "$why")"
  fi
  rm -f "$why"
}

# A broken gate's question to the log, given the message the operator is
# shown, which is why it came to them: the message's parts where the gate had
# made them, the question as last read otherwise. Nothing where the gate held
# no question: a reply it could not read may have asked nothing.
log_broken() {
  local message="$1" parts asked
  [ -n "${history:-}" ] && [ -n "${session:-}" ] && [ -n "${record:-}" ] || return 0
  parts="$(to_operator_parts "$record")"
  if [ -z "$parts" ]; then
    asked="$(to_asked "$record")"
    [ -n "$asked" ] || return 0
    parts="$(jq -c '{question, approved: ""}' <<<"$asked")"
  fi
  log_let_go "$parts" "" "$message" ""
}

# The reply to the plain retelling: the operator's message made and shown,
# and the question let go. The retold question is read by the reader; where it
# cannot be, the question as first asked opens the message, saying so. The
# summary never holds the question up either: where it fails, the operator
# is told why and shown the answers as given.
answer_retold() {
  local parts question retold="" extra="" why form exchange summary="" failed="" story message why_lines logged
  parts="$(to_operator_parts "$record")"
  if [ -z "$parts" ]; then
    refuse_state_unreadable_note "$record_file" >&2
    exit 1
  fi
  question="$(jq -r '.question' <<<"$parts")"
  why="$(mktemp)"
  if form="$(get_reader_form "$reply" 2>"$why")" && jq -e '.asks_operator' >/dev/null <<<"$form"; then
    question="$(jq -r '.question' <<<"$form")"
    retold="$question"
  else
    extra="$(gate_retelling_unread_line "$(cat "$why")")"
  fi
  record="$(with_turn "$record" "$EXCHANGE_AGENT" "$reply")"
  exchange="$(to_exchange "$record")"
  if ! summary="$(get_summary "$exchange" 2>"$why")"; then
    summary=""
    failed="$(cat "$why")"
  fi
  rm -f "$why"
  story="$(to_operator_story "$parts" "$summary" "$failed")"
  message="$(to_operator_message "$parts" "$question" "$extra" "$story")"
  why_lines="$(jq -r '.why' <<<"$parts")"
  [ -z "$extra" ] || why_lines+=$'\n'"$extra"
  logged="$(log_let_go "$parts" "$retold" "$why_lines" "$summary")"
  [ -z "$logged" ] || message+=$'\n'"$logged"
  record="$(with_chain_reset "$record")"
  keep_record
  to_operator_answer "$message"
  exit 0
}

# Put a question on the ladder: its first rung is the form in hand, and the
# agent is sent the first challenge. The lines given are shown to the
# operator beside whatever the ladder brings them.
start_ladder() {
  local form="$1" kind="$2" lines="$3" question first ladder name words
  question="$(jq -r '.question' <<<"$form")"
  first="$(to_first_answer "$form")"
  record="$(with_ladder "$record" "$question" "$kind" "$lines" "$first")"
  ladder="$(to_ladder "$record")"
  name="$(to_rung_message_name "$ladder")"
  words="$(ladder_message "$name")"
  send_back "$(gate_challenge_note "$words")" "$question"
}

# An answer that held on every rung. Every kind is on trial until the
# operator switches it, and nothing switches one yet, so a held answer still
# comes to them, marked with what the stand-in would have approved: trust is
# gained on their yes, never assumed. This is the one place a switched kind
# would instead let the reply stop silently.
answer_held() {
  local ladder="$1" question recommended why
  question="$(jq -r '.question' <<<"$ladder")"
  recommended="$(jq -r '.first.recommended' <<<"$ladder")"
  why="$(to_held_why "$ladder")"
  bring_operator "$question" "$why" "$recommended"
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
# lead it, and code could not tell whether it ran. The reading rides this
# stop beside the matcher alone, since no stop has room for it beside the
# summary too. It never holds the question up: where it fails or runs out of
# time, the operator is told why there is none.
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
    *) answer_changed ;;
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
  log_let_go "$parts" "" "$why" "" "$step"
}

# Let a step's report stop, showing the operator the message given and,
# under it, any line the log gave back.
let_step_stop() {
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
# sent no plain retelling and given no summary: a step's report is not a
# question, and the note beside it says only why the go is theirs.
step_to_operator() {
  local form="$1" sort="$2" entry="$3" why="$4" question logged
  question="$(to_step_question "$form")"
  logged="$(log_step "$form" "$sort" "$entry" "$question" "" "$why" "$OUTCOME_TO_OPERATOR")"
  let_step_stop "$(gate_step_operator_note "$question" "$why")" "$logged"
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
  if is_on_trial "$entry"; then
    why="$(gate_trial_line "$(jq -r '.name' <<<"$entry")")"
    logged="$(log_step "$form" "$sort" "$entry" "$question" "$(step_go_words)" "$why" "$OUTCOME_WOULD_HAVE_APPROVED")"
    let_step_stop "$(to_go_message "$question" "$why" "$fixed")" "$logged"
  fi
  logged="$(log_step "$form" "$sort" "$entry" "$question" "$(step_go_words)" "" "$OUTCOME_SETTLED")"
  if [ -n "$logged" ]; then
    let_step_stop "$(to_go_message "$question" "$logged" "$fixed")" ""
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
  local form="$1" entry sort briefs labels step words
  entry="$(find_go_kind "$preset")"
  [ -n "$entry" ] || let_stop
  sort="$(get_step_sort "$form" "$reply" "$preset")"
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

# Take the route the question's forms decide.
route_question() {
  local form="$1" sort="$2" entry="$3" kept="$4" risks route words question
  question="$(jq -r '.question' <<<"$form")"
  risks="$(list_risks "$preset")"
  route="$(derive_route "$form" "$sort" "$entry" "$risks" "$kept")"
  words="$(jq -r '.words' <<<"$route")"
  case "$(jq -r '.route' <<<"$route")" in
    agent) send_back "$words" "$question" ;;
    operator) bring_operator "$question" "$words" ;;
    ladder) start_ladder "$form" "$(jq -r '.name' <<<"$entry")" "$words" ;;
  esac
}

# The ladder a round after the rungs answers, left in the variable ladder. A
# record awaiting such a round with no ladder is one the gate did not write.
take_ladder() {
  ladder="$(to_ladder "$record")"
  [ -n "$ladder" ] || { refuse_state_unreadable_note "$record_file" >&2; exit 1; }
}

# A fixed round awaiting its reply takes this reply, whatever it says. A
# round the gate does not know is a record it did not write.
round="$(to_round "$record")"
case "$round" in
  "") ;;
  "$LADDER_PLAIN_RETELLING") answer_retold ;;
  "$LADDER_BIGGER_LOOK") take_ladder; answer_looked ;;
  "$LADDER_SURE_AGAIN") take_ladder; answer_sure_again ;;
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
    # Dropped: noted, and the reply is read on as any other, since it may
    # go on to ask something else.
    drop) record="$(with_dropped "$record")" ;;
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

# A reply asking nothing stops as it is, unless it reports a step finished:
# that one waits for a go, which the step go weighs.
if ! jq -e '.asks_operator' >/dev/null <<<"$form"; then
  if jq -e '.ends_step' >/dev/null <<<"$form"; then answer_step "$form"; fi
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
first="$(jq -r '.challenge' <<<"$entry")"
if [ -n "$first" ]; then
  record="$(with_challenge "$record" "$entry" 1 "$form" "$sort")"
  send_back "$(gate_challenge_note "$first")" "$question"
fi

route_question "$form" "$sort" "$entry" false
