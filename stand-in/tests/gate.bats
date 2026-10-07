bats_require_minimum_version 1.5.0

# Behavior tests for the gate: silent where the stand-in is off, every route a
# question can take, the challenge and its answers, the ladder, the bigger
# look around, "are you sure?" once more and the cold second reading, every
# question reaching the operator in the stop that decides it is theirs, as
# asked and with the summary's parts under it, the loop guard, the step go, the round's
# decisions laid out before building, the kinds accepted as they stand and
# those given one challenge, the trial and the switched kind, a proposal
# dropped and a decision reopened, the closing loop and its end report, and
# every way the gate itself can fail letting the reply stop with a reason.
# Claude Code is the suite's own fake, answering each model apart.

load fake-claude
load question-log
load process-group

setup() {
  setup_fake_claude
  gate="$BATS_TEST_DIRNAME/../hooks/gate.sh"
  . "$lib/words.sh"
  . "$lib/jobs.sh"
  . "$lib/forms.sh"
  . "$lib/record.sh"
  . "$lib/ladder.sh"
  preset "defaults:Defaults. naming:Names." "security-gap workaround"
  kind defaults ladder
  kind naming ask
  rules="$project/rules"
  conventions="$project/conventions"
  mkdir -p "$rules" "$conventions"
  printf '# Rule one\n\nRule one body.\n' >"$rules/rule-one.md"
  printf '# Rules\n' >"$rules/README.md"
  printf '# Convention one\n\nConvention one body.\n' >"$conventions/convention-one.md"
  printf 'AIDK_RULES=%s\nAIDK_CONVENTIONS=%s\n' "$rules" "$conventions" >>"$project/aidk-config.env"
  session="session-1"
  history="$project/aidk-stand-in"
  record_file="$history/sessions/$session.json"
  switch_on "$session"
  reply="Should we use five retries or ten? I recommend five."
  # The case-writer's command, as the agent is told to type it.
  cases_command="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/stand-in.sh write-cases"
  answer_for reader "$(whole_form)"
  answer_for checker "$(clean_check)"
  answer_for sorter '{"kind":"defaults","unsure":false,"risks":[],"defers":false}'
  answer_for summary "$(summary_form)"
}

teardown() {
  local stopped=0
  stop_group || stopped=$?
  [ ! -d "$history" ] || chmod -R u+rwx "$history"
  chmod u+rwx "$preset_dir/questions"
  return "$stopped"
}

# A kind of question in the suite's preset: name, route, and its first and
# second challenge where it has them.
kind() {
  {
    printf -- '---\nsummary: The %s kind.\nroute: %s\n' "$1" "$2"
    [ -z "${3:-}" ] || printf 'challenge: %s\n' "$3"
    [ -z "${4:-}" ] || printf 'second-challenge: %s\n' "$4"
    printf -- '---\n\n# %s\n' "$1"
  } >"$preset_dir/questions/$1.md"
}

# The stand-in switched on for a session, as its entry command leaves it.
switch_on() {
  mkdir -p "$history/on"
  : >"$history/on/$1"
}

# A checker's answer that finds nothing.
clean_check() {
  printf '%s' '{"breaks":[],"miscalled":[],"explains_code":false}'
}

# A reader's form for a reply asking nothing, answering a challenge as given.
no_question_form() {
  printf '{"asks_operator":false,"question":"","options":[],"recommended":"","claims_done":false,"closes_round":false,"guidance_answer":"%s","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}' "${1:-}"
}

# The end-of-reply event, as Claude Code hands it to a Stop hook.
stop_event() {
  jq -cn --arg session "$1" --arg reply "$2" --argjson active "$3" \
    '{session_id: $session, transcript_path: "/nowhere", hook_event_name: "Stop",
      stop_hook_active: $active, last_assistant_message: $reply}'
}

# The gate, run on a stop of the suite's session.
run_gate() {
  run --separate-stderr "$gate" <<<"$(stop_event "$session" "${2:-$reply}" "${1:-false}")"
}

# The block answer the gate gave, and the operator's message, out of its
# output.
reason() { jq -r '.reason' <<<"$output"; }
message() { jq -r '.systemMessage' <<<"$output"; }

# A reader's form of a reply still asking the question, recommending the label
# given from the options given, as a JSON array, five and ten by default.
rung_form() {
  jq -cn --arg recommended "$1" --argjson options "${2:-[\"five\",\"ten\"]}" \
    '{asks_operator: true, question: "Five retries or ten?", options: $options,
      recommended: $recommended, claims_done: false, closes_round: false, guidance_answer: "", ends_step: false, problems: [],
      proof: "", next_step: "", next_step_number: 0, next_step_from: "", next_step_marks: []}'
}

# The matcher's pick of a reply: an item of the first options, a new choice,
# or the question let go.
item() { jq -cn --arg item "$1" '{pick: "item", item: $item}'; }
new_pick() { printf '%s' '{"pick":"new","item":""}'; }
gone_pick() { printf '%s' '{"pick":"not-asking","item":""}'; }

# The ladder climbed from the suite's question: the first stop puts it on the
# ladder, and each pick given is the matcher's of the reply to the next rung,
# in order. The gate's answer to the last stop is left in output.
climb() {
  run_gate
  local pick
  for pick in "$@"; do
    answer_for matcher "$pick"
    run_gate true
  done
}

# The question as the agent asks it, as the suite's reader reads it.
asked="Five retries or ten?"

# The suite's summary's parts as the operator reads them, spelled here in the
# operator's order, the reading's part given standing before the call.
story() {
  local summary
  summary="$(summary_form)"
  gate_problem_part "$(jq -r '.problem' <<<"$summary")"
  gate_first_recommendation_part "$(jq -r '.first_recommendation' <<<"$summary")"
  gate_what_moved_part "$(jq -r '.what_moved_it' <<<"$summary")"
  gate_recommends_now_part "$(jq -r '.recommends_now' <<<"$summary")"
  [ -z "${1:-}" ] || printf '%s\n' "$1"
  gate_operator_call_part "$(jq -r '.operators_call' <<<"$summary")"
}

# The stop just run brought the question to the operator: the reply stops
# with their message, nothing more is asked of the agent for it, and nothing
# of it is held over to a later stop.
answered_operator() {
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ -n "$(message)" ]
  is_record_idle "$(read_session_record "$record_file")"
  [ "$(jq -c '.exchange' <<<"$(read_session_record "$record_file")")" = '[]' ]
}

# The operator's message for the question given, as asked, given why it came
# to them, then the summary's parts, the reading part among them where one is
# given.
operator_message_for() {
  printf '%s\n%s' "$(gate_operator_note "$1" "$2")" "$(story "${3:-}")"
}

# The same message for the suite's own question.
operator_message() {
  operator_message_for "$asked" "$@"
}

# The operator's message for answers that held, given why they came.
held_message() {
  printf '%s\n%s' "$(gate_held_note "$asked" five 3 "$1")" "$(story)"
}

# The calls a whole question is read by, in order, each on its job's model.
all_three() {
  printf 'reader %s\nchecker %s\nsorter %s' "$READER_MODEL" "$CHECKER_MODEL" "$SORTER_MODEL"
}

@test "a session the stand-in is off for passes silently, and no model is asked" {
  rm "$history/on/$session"
  run_gate
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$(calls)" ]
  rm -r "$history"
  run_gate
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$(calls)" ]
}

@test "a reply asking the operator nothing stops as it is, read by the reader alone" {
  answer_for reader "$(no_question_form)"
  run_gate
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
  [ ! -e "$record_file" ]
  grep -qF -- "$reply" "$FAKE_PROMPT.reader"
}

@test "a question with no recommendation goes back to the agent to state one" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"closes_round":false,"guidance_answer":"","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}'
  run_gate
  [ "$status" -eq 0 ]
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(gate_no_recommendation_note)" ]
  # Every message the stand-in sends an agent opens so.
  [[ "$(reason)" == "From the stand-in: "* ]]
  [ "$(calls)" = "$(all_three)" ]
}

@test "a broken rule or convention sends the question back, naming each entry and where it lies" {
  answer_for checker '{"breaks":[{"entry":"convention-one.md","why":"Five breaks it."},{"entry":"rule-one.md","why":"So does this."}],"miscalled":[],"explains_code":false}'
  run_gate
  [ "$status" -eq 0 ]
  lines="$(gate_breaks_line "$(convention_words)" convention-one.md "$conventions/convention-one.md" "Five breaks it.")"$'\n'
  lines+="$(gate_breaks_line "$(rule_words)" rule-one.md "$rules/rule-one.md" "So does this.")"$'\n'
  [ "$(reason)" = "$(gate_checker_sendback_note "$lines")" ]
  [ "$(calls)" = "reader $READER_MODEL"$'\n'"checker $CHECKER_MODEL" ]
}

@test "something called a rule that no entry is sends the question back, saying what it is" {
  answer_for checker '{"breaks":[],"miscalled":[{"called":"the frame'\''s current rule","actually":"a code comment"}],"explains_code":false}'
  run_gate
  [ "$status" -eq 0 ]
  [ "$(reason)" = "$(gate_checker_sendback_note "$(gate_miscalled_line "the frame's current rule" "a code comment")"$'\n')" ]
}

@test "a convention sentence explaining how code works sends the question back" {
  answer_for checker '{"breaks":[],"miscalled":[],"explains_code":true}'
  run_gate
  [ "$status" -eq 0 ]
  [ "$(reason)" = "$(gate_checker_sendback_note "$(gate_explains_code_line)"$'\n')" ]
}

@test "the checker is handed every rule and convention whole, and nothing that is not an entry" {
  run_gate
  standing="$FAKE_STANDING.checker"
  grep -qxF "=====ENTRY rule-one.md=====" "$standing"
  grep -qxF "Rule one body." "$standing"
  grep -qxF "=====ENTRY convention-one.md=====" "$standing"
  grep -qxF "Convention one body." "$standing"
  # Counted rather than negated: a negated command does not fail a test.
  [ "$(grep -cF "=====ENTRY README.md=====" "$standing")" -eq 0 ]
  grep -qF -- "$reply" "$FAKE_PROMPT.checker"
  grep -qF -- '"enum":["convention-one.md","rule-one.md"]' "$FAKE_ARGS.checker"
}

@test "a kind with a challenge is challenged first, and a drop is logged and lets the reply stop" {
  kind naming ask "Do we really need it?" "Have you read them?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate
  [ "$status" -eq 0 ]
  [ "$(reason)" = "$(gate_challenge_note "Do we really need it?")" ]
  answer_for reader "$(no_question_form drop)"
  rm "$FAKE_CALLS"
  run_gate true "Dropped: the default stands."
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
  # A line of its own, never awaiting the operator's answer, with the options
  # it offered for whoever reopens it.
  [ "$(jq -c '{number, question, kind, outcome, approved, reasons, summary, dropped, answer}' "$(log_file)")" = \
    '{"number":1,"question":"Five retries or ten?","kind":"naming","outcome":"dropped","approved":"","reasons":[],"summary":null,"dropped":{"options":["five","ten"],"recommended":"five"},"answer":""}' ]
  [ "$(jq 'has("retold")' "$(log_file)")" = false ]
  [ "$(jq -c '[.exchange[] | .text]' "$(log_file)")" = \
    "$(jq -cn --arg a "$reply" --arg b "$(gate_challenge_note "Do we really need it?")" '[$a, $b, "Dropped: the default stands."]')" ]
  [ "$(jq -c . "$record_file")" = "$EMPTY_RECORD" ]
  run "$BATS_TEST_DIRNAME/../hooks/answer-hook.sh" <<<"$(jq -cn --arg s "$session" '{session_id: $s, hook_event_name: "UserPromptSubmit", prompt: "fine"}')"
  [ "$(jq -r '.answer' "$(log_file)")" = "" ]
  # A drop is no decision of the round laid out before building.
  answer_for reader "$(jq -c '.asks_operator = false | .question = "" | .options = [] | .recommended = "" | .closes_round = true' <<<"$(whole_form)")"
  run_gate false "Shall I start building?"
  [ "$(message)" = "$(round_heading; round_empty_line; round_hint)" ]
}

@test "a drop that cannot be logged lets the reply stop, the operator told it is listed nowhere" {
  kind naming ask "Do we really need it?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate
  mkdir -p "$history/log"
  chmod a-w "$history/log"
  answer_for reader "$(no_question_form drop)"
  run_gate true
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(gate_drop_unlogged_note "Five retries or ten?"; gate_log_failed_line "$(refuse_log_unwritable_note "$history/log")")" ]
}

@test "a proposal kept is challenged a second time, and kept again goes to the operator" {
  kind naming ask "Do we really need it?" "Have you read them?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate
  answer_for reader "$(no_question_form keep-part)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "Have you read them?")" ]
  answer_for reader "$(no_question_form keep-all)"
  run_gate true
  answered_operator
  why="$(gate_kind_line naming "The naming kind.")"$'\n'"$(gate_kept_line)"
  [ "$(message)" = "$(operator_message "$why")" ]
  [ "$(jq -c '.challenge' "$record_file")" = null ]
}

@test "a proposal kept under a one-step challenge goes on to the routes" {
  kind naming ask "Do we really need it?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate
  answer_for reader "$(no_question_form keep-all)"
  rm "$FAKE_CALLS"
  run_gate true "Kept: five."
  answered_operator
  why="$(gate_kind_line naming "The naming kind.")"$'\n'"$(gate_kept_line)"
  [ "$(message)" = "$(operator_message "$why")" ]
  # The challenge's reply is read, then the summary is written, in one stop,
  # from the whole exchange, the reply that kept it last.
  [ "$(calls)" = "reader $READER_MODEL"$'\n'"summary $SUMMARY_MODEL" ]
  challenged="$(grep -nxF -- "$(gate_challenge_note "Do we really need it?")" "$FAKE_PROMPT.summary" | cut -d: -f1)"
  kept="$(grep -nxF -- "Kept: five." "$FAKE_PROMPT.summary" | cut -d: -f1)"
  [ "$kept" -gt "$challenged" ]
}

@test "a reply that answers the challenge neither way goes to the operator" {
  kind naming ask "Do we really need it?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate
  answer_for reader "$(no_question_form)"
  run_gate true
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_unanswered_line "Do we really need it?")")" ]
}

@test "an always-yours kind reaches the operator in the stop that sorts it: the question as asked, why, then the summary" {
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_kind_line naming "The naming kind.")")" ]
  [[ "$(message)" == "Stand-in: a question for you: Five retries or ten?"$'\n'* ]]
  # One stop: the question is read, checked and sorted, then the summary is
  # written from the exchange, which is the reply alone.
  [ "$(calls)" = "$(all_three)"$'\n'"summary $SUMMARY_MODEL" ]
  . "$lib/summary.sh"
  grep -qxF -- "$reply" "$FAKE_PROMPT.summary"
  [ "$(grep -cxF -- "$SUMMARY_AGENT_MARKER" "$FAKE_PROMPT.summary")" -eq 1 ]
  [ "$(grep -cxF -- "$SUMMARY_STAND_IN_MARKER" "$FAKE_PROMPT.summary")" -eq 0 ]
  [ "$(read_session_record "$record_file")" = "$EMPTY_RECORD" ]
}

@test "a risk named on the recommended option goes to the operator, with the risk's words" {
  answer_for sorter '{"kind":"defaults","unsure":false,"risks":["workaround"],"defers":false}'
  run_gate
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_risk_line five workaround "The workaround risk.")")" ]
}

@test "a sort the sorter is unsure of goes to the operator" {
  answer_for sorter '{"kind":"defaults","unsure":true,"risks":[],"defers":false}'
  run_gate
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_unsure_line defaults)")" ]
}

@test "a summary that fails never holds the question: the operator is told why and shown the answers" {
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  status_for summary 124
  run_gate
  answered_operator
  expected="$(gate_operator_note "$asked" "$(gate_kind_line naming "The naming kind.")")"$'\n'
  expected+="$(gate_summary_failed_note "$(refuse_model_timeout_note "$SUMMARY_MODEL" "$SUMMARY_SECONDS")")"$'\n'
  expected+="$(gate_answers_heading; gate_answer_line 1 five "five${LADDER_OPTION_SEPARATOR}ten")"
  [ "$(message)" = "$expected" ]
}

# A command of the suite's own in place of the one named, which fails, saying
# so on stderr, where any of its arguments holds the words given, taken
# literally and holding no single quote, and runs the real one otherwise.
fail_command_on() {
  local real
  real="$(command -v "$1")"
  printf '#!/usr/bin/env bash\nfor a in "$@"; do case "$a" in *'\''%s'\''*) echo "%s: refused by the suite" >&2; exit 5 ;; esac; done\nexec %s "$@"\n' \
    "$2" "$1" "$real" >"$fakebin/$1"
  chmod +x "$fakebin/$1"
}

# regression: the summary's answer check ran inside an if's condition, with
# errexit off, so a check that failed found no problem and the summary passed
# unchecked to the operator.
@test "a summary whose answer check fails is no summary: the operator is told why and shown the answers" {
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  fail_command_on jq summary-part-empty
  run_gate
  answered_operator
  expected="$(gate_operator_note "$asked" "$(gate_kind_line naming "The naming kind.")")"$'\n'
  expected+="$(gate_summary_failed_note "jq: refused by the suite")"$'\n'
  expected+="$(gate_answers_heading; gate_answer_line 1 five "five${LADDER_OPTION_SEPARATOR}ten")"
  [ "$(message)" = "$expected" ]
}

# regression: the log's write ran on the left of a ||, with errexit off, so a
# line whose id could not be minted was written with none, and the operator
# never heard.
@test "a log line whose id cannot be minted is not written: the operator is told the question is not logged" {
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  fail_command_on od urandom
  run_gate
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_kind_line naming "The naming kind.")")"$'\n'"$(gate_log_failed_line "od: refused by the suite")" ]
  [ ! -s "$(log_file)" ]
}

@test "a ladder kind with no risk, sorted for certain, is sent the ladder's first challenge" {
  run_gate
  [ "$status" -eq 0 ]
  [ "$(reason)" = "$(gate_challenge_note "$standing_test")" ]
  [[ "$(reason)" == "From the stand-in: $standing_test"* ]]
  [ "$(jq -c '.ladder.first' "$record_file")" = '{"options":["five","ten"],"recommended":"five"}' ]
  [ "$(jq -c '.ladder.picks' "$record_file")" = '[]' ]
}

@test "the same item in other words on every rung holds, and during the trial still comes to the operator" {
  run_gate
  answer_for matcher "$(item five)"
  rm "$FAKE_CALLS"
  run_gate true "5 attempts is what I would pick."
  [ "$(reason)" = "$(gate_challenge_note "$are_you_sure")" ]
  # A rung is matched, never read again.
  [ "$(calls)" = "matcher $MATCHER_MODEL" ]
  grep -qxF -- "5 attempts is what I would pick." "$FAKE_PROMPT.matcher"
  run_gate true "Let's stay with five tries."
  answered_operator
  [ "$(message)" = "$(held_message "$(gate_trial_line defaults)")" ]
  [[ "$(message)" == "Stand-in: a question for you: $asked"$'\n'* ]]
  # The last rung's stop matches the reply, then writes the summary: no
  # reader, and no further stop.
  [ "$(calls)" = "matcher $MATCHER_MODEL"$'\n'"matcher $MATCHER_MODEL"$'\n'"summary $SUMMARY_MODEL" ]
  grep -qxF -- "Let's stay with five tries." "$FAKE_PROMPT.summary"
  [ "$(jq -c '.ladder' "$record_file")" = null ]
}

@test "an answer that moves, then moves again after the bigger look, gets the reading and reaches the operator in that stop" {
  answer_for reading '{"reading":"Ten is safer."}'
  climb "$(item ten)"
  rm "$FAKE_CALLS"
  answer_for matcher "$(item five)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$bigger_look")" ]
  [ "$(calls)" = "matcher $MATCHER_MODEL" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 2 ]
  # The bigger look's reply is matched alone, and "are you sure?" is sent once
  # more, in the rung's own words, outside the send-back count.
  rm "$FAKE_CALLS"
  answer_for matcher "$(item ten)"
  run_gate true "I looked further: ten."
  [ "$(reason)" = "$(gate_challenge_note "$are_you_sure")" ]
  [ "$(calls)" = "matcher $MATCHER_MODEL" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 2 ]
  # Moved again: the reading runs on this stop, then the summary, and the
  # question reaches the operator.
  rm "$FAKE_CALLS"
  answer_for matcher "$(item five)"
  run_gate true "On reflection, five."
  answered_operator
  [ "$(calls)" = "matcher $MATCHER_MODEL"$'\n'"reading $READING_MODEL"$'\n'"summary $SUMMARY_MODEL" ]
  [ "$(message)" = "$(operator_message "$(gate_moved_line)" "$(gate_reading_note "Ten is safer.")")" ]
  [ "$(jq -c '.ladder.picks' "$(log_file)")" = "[$(item ten),$(item five),$(item ten),$(item five)]" ]
  # Each fixed round went to the agent once, "are you sure?" twice in all, and
  # the summary was handed the whole exchange, the last reply in it.
  [ "$(grep -cxF -- "$(gate_challenge_note "$bigger_look")" "$FAKE_PROMPT.summary")" -eq 1 ]
  [ "$(grep -cxF -- "$(gate_challenge_note "$are_you_sure")" "$FAKE_PROMPT.summary")" -eq 2 ]
  grep -qxF -- "$(gate_challenge_note "$standing_test")" "$FAKE_PROMPT.summary"
  grep -qxF -- "I looked further: ten." "$FAKE_PROMPT.summary"
  grep -qxF -- "On reflection, five." "$FAKE_PROMPT.summary"
  [ "$(jq -c '.ladder' "$record_file")" = null ]
}

@test "an answer that moves, then holds after the bigger look, gets no reading, and reaches the operator told so, never as held" {
  answer_for reading '{"reading":"Ten is safer."}'
  climb "$(item ten)" "$(item five)" "$(item ten)"
  [ "$(reason)" = "$(gate_challenge_note "$are_you_sure")" ]
  rm "$FAKE_CALLS"
  answer_for matcher "$(item ten)"
  run_gate true "Yes, ten."
  answered_operator
  [ "$(calls)" = "matcher $MATCHER_MODEL"$'\n'"summary $SUMMARY_MODEL" ]
  grep -qxF -- "Yes, ten." "$FAKE_PROMPT.summary"
  [ "$(message)" = "$(operator_message "$(gate_moved_then_held_line)")" ]
  # Held after moving never earns the would-have-approved mark.
  [ "$(jq -c '{outcome, approved, reading, reasons}' "$(log_file)")" = \
    "$(jq -cn --arg why "$(gate_moved_then_held_line)" '{outcome: "to-operator", approved: "", reading: null, reasons: [$why]}')" ]
  [ "$(calls | grep -c '^reading ')" -eq 0 ]
}

@test "the operator's message shows the question as asked, why, then the summary's parts, the reading before the call" {
  answer_for reading '{"reading":"Ten is safer."}'
  climb "$(item ten)" "$(item five)" "$(item ten)" "$(item five)"
  answered_operator
  summary="$(summary_form)"
  expected="$(gate_operator_note "Five retries or ten?" "$(gate_moved_line)")"$'\n'
  expected+="$(gate_problem_part "$(jq -r '.problem' <<<"$summary")")"$'\n'
  expected+="$(gate_first_recommendation_part "$(jq -r '.first_recommendation' <<<"$summary")")"$'\n'
  expected+="$(gate_what_moved_part "$(jq -r '.what_moved_it' <<<"$summary")")"$'\n'
  expected+="$(gate_recommends_now_part "$(jq -r '.recommends_now' <<<"$summary")")"$'\n'
  expected+="$(gate_reading_note "Ten is safer.")"$'\n'
  expected+="$(gate_operator_call_part "$(jq -r '.operators_call' <<<"$summary")")"
  [ "$(message)" = "$expected" ]
  # The log keeps the parts as the operator was shown them.
  [ "$(jq -c '.summary' "$(log_file)")" = "$(summary_form)" ]
}

@test "the cold reading is the advisor's command, handed the question and options alone, reading the project" {
  answer_for reading '{"reading":"Ten is safer."}'
  climb "$(item ten)" "$(item five)" "$(item five)" "$(item ten)"
  prompt="$FAKE_PROMPT.reading"
  grep -qxF "Answer one claim about the code." "$prompt"
  grep -qxF "Five retries or ten?" "$prompt"
  grep -qxF -- "- five" "$prompt"
  grep -qxF -- "- ten" "$prompt"
  grep -qF -- "$rules" "$prompt"
  grep -qF -- "$conventions" "$prompt"
  # Counted rather than negated: a negated command does not fail a test.
  [ "$(grep -ci "recommend" "$prompt")" -eq 0 ]
  grep -qx "Read,Grep,Glob" "$FAKE_ARGS.reading"
  [ "$(cat "$FAKE_ARGS.reading.pwd")" = "$project" ]
  # Cold means it cannot read the stand-in's own folder either: each of its
  # tools is denied the folder the configuration names.
  settings="$(grep -A1 -x -- --settings "$FAKE_ARGS.reading" | tail -n 1)"
  jq -e --arg read "Read(/$history/**)" --arg grep "Grep(/$history/**)" --arg glob "Glob(/$history/**)" \
    '. == {disableAllHooks: true, permissions: {deny: [$read, $grep, $glob]}}' <<<"$settings"
}

@test "the matcher is handed the first options and the reply, never the recommendation" {
  climb "$(item five)"
  prompt="$FAKE_PROMPT.matcher"
  grep -qxF "Five retries or ten?" "$prompt"
  grep -qxF -- "- five" "$prompt"
  grep -qxF -- "- ten" "$prompt"
  grep -qxF -- "$reply" "$prompt"
  [ "$(grep -ci "recommended" "$prompt")" -eq 0 ]
}

@test "a new choice on a rung counts as a change" {
  answer_for reading '{"reading":"Either."}'
  climb "$(item five)" "$(new_pick)"
  [ "$(reason)" = "$(gate_challenge_note "$bigger_look")" ]
  climb "$(new_pick)" "$(item five)"
  [ "$(reason)" = "$(gate_challenge_note "$bigger_look")" ]
}

@test "a rung whose reply no longer asks the question counts as a change, and the last rung is still asked" {
  run_gate
  answer_for matcher "$(gone_pick)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$are_you_sure")" ]
  answer_for matcher "$(item five)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$bigger_look")" ]
}

@test "a reading that fails still brings the operator the question, saying why there is none" {
  status_for reading 124
  climb "$(item ten)" "$(item five)" "$(item five)" "$(item ten)"
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_moved_line)" \
    "$(gate_reading_failed_line "$(refuse_model_timeout_note "$READING_MODEL" "$READING_SECONDS")")")" ]
  rm "$FAKE_ANSWERS/reading.status"
  answer_for reading '{"reading":"  "}'
  climb "$(item ten)" "$(item five)" "$(item five)" "$(item ten)"
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_moved_line)" "$(gate_reading_failed_line "$(refuse_reading_empty_note)")")" ]
}

@test "a summary that fails after a ladder shows every answer, the bigger look's and the one after it marked" {
  answer_for reading '{"reading":"Either."}'
  status_for summary 3
  climb "$(item ten)" "$(new_pick)" "$(gone_pick)" "$(item five)"
  answered_operator
  list="five${LADDER_OPTION_SEPARATOR}ten"
  expected="$(gate_operator_note "$asked" "$(gate_moved_line)")"$'\n'
  expected+="$(gate_summary_failed_note "$(refuse_model_exit_note "$SUMMARY_MODEL" 3)")"$'\n'
  expected+="$(gate_answers_heading
    gate_answer_line 1 five "$list"
    gate_pick_line 2 ten
    gate_pick_new_line 3
    gate_answer_gone_line "$(gate_looked_number 4)"
    gate_pick_line "$(gate_sure_again_number 5)" five)"$'\n'
  expected+="$(gate_reading_note "Either.")"
  [ "$(message)" = "$expected" ]
}

@test "a question kept through its challenge goes up the ladder, the operator told it was kept" {
  kind defaults ladder "Do we really need it?"
  run_gate
  answer_for reader "$(no_question_form keep-all)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$standing_test")" ]
  [ "$(jq -c '.challenge' "$record_file")" = null ]
  answer_for matcher "$(item five)"
  run_gate true
  run_gate true
  answered_operator
  [ "$(message)" = "$(held_message "$(gate_trial_line defaults)"$'\n'"$(gate_kept_line)")" ]
}

@test "a preset whose ladder lacks any named message goes to the operator, whichever is needed now" {
  ladder_file="$preset_dir/challenges/challenge-ladder.md"
  for name in standing-test are-you-sure bigger-look; do
    ladder_file "$standing_test" "$are_you_sure" "$bigger_look" \
      | sed "s/\`$name\`/\`renamed\`/" >"$ladder_file"
    run_gate
    [ "$status" -eq 0 ]
    [ "$(message)" = "$(gate_broken_note "$(refuse_ladder_message_missing_note "$ladder_file" "$name")")" ]
  done
  # A question bound for the operator needs no message of the ladder's.
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_kind_line naming "The naming kind.")")" ]
  answer_for sorter '{"kind":"defaults","unsure":false,"risks":[],"defers":false}'
  printf -- '---\nsummary: Ladder.\n---\n\n2. Then:\n   > Clean?\n' >"$ladder_file"
  run_gate
  [ "$(message)" = "$(gate_broken_note "$(refuse_unnamed_message_note "$ladder_file" 6)")" ]
  rm "$ladder_file"
  run_gate
  [ "$(message)" = "$(gate_broken_note "$(refuse_unreadable_file_note "$ladder_file")")" ]
}

@test "a matcher that fails lets the reply stop with the reason, and asks the agent nothing more" {
  run_gate
  status_for matcher 124
  run_gate true
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_model_timeout_note "$MATCHER_MODEL" "$MATCHER_SECONDS")")" ]
}

@test "the ladder's challenges count toward the send-back limit, and the loop guard brings the operator the question in that stop" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"closes_round":false,"guidance_answer":"","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}'
  run_gate false
  run_gate true
  answer_for reader "$(rung_form five)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$standing_test")" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  answer_for matcher "$(item five)"
  rm "$FAKE_CALLS"
  run_gate true
  answered_operator
  [ "$(calls)" = "matcher $MATCHER_MODEL"$'\n'"summary $SUMMARY_MODEL" ]
  [ "$(message)" = "$(operator_message "$(gate_loop_line 3 "$(gate_challenge_note "$are_you_sure")")")" ]
  [ "$(jq -c '.ladder' "$record_file")" = null ]
}

@test "the fixed rounds are never counted: a ladder at the limit is still sent the bigger look, and reaches the operator after it" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"closes_round":false,"guidance_answer":"","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}'
  answer_for reading '{"reading":"Ten is safer."}'
  run_gate false
  answer_for reader "$(rung_form five)"
  run_gate true
  answer_for matcher "$(item five)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$are_you_sure")" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  answer_for matcher "$(item ten)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$bigger_look")" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$are_you_sure")" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  answer_for matcher "$(item five)"
  run_gate true
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_moved_line)" "$(gate_reading_note "Ten is safer.")")" ]
}

# The suite's session record changed by the jq filter given.
edit_record() {
  jq -c "$1" "$record_file" >"$record_file.new" && mv "$record_file.new" "$record_file"
}

@test "a fixed round already sent for the question is never sent again" {
  climb "$(item ten)"
  edit_record '.rounds_sent = ["bigger-look"]'
  answer_for matcher "$(item five)"
  run_gate true
  [ "$(message)" = "$(gate_broken_note "$(refuse_round_twice_note bigger-look)")" ]
  # "Are you sure?" once more is sent once, whatever the bigger look answered.
  climb "$(item ten)" "$(item five)"
  [ "$(reason)" = "$(gate_challenge_note "$bigger_look")" ]
  edit_record ".rounds_sent += [\"$LADDER_SURE_AGAIN\"]"
  answer_for matcher "$(item ten)"
  run_gate true
  [ "$(message)" = "$(gate_broken_note "$(refuse_round_twice_note "$LADDER_SURE_AGAIN")")" ]
}

@test "a new turn of the operator's drops a ladder in progress" {
  run_gate
  answer_for reader "$(no_question_form)"
  run_gate false
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(jq -c '.ladder' "$record_file")" = null ]
  answer_for reader "$(rung_form five)"
  run_gate
  [ "$(jq '.ladder.picks | length' "$record_file")" -eq 0 ]
  rm "$FAKE_CALLS"
  run_gate false
  [ "$(reason)" = "$(gate_challenge_note "$standing_test")" ]
  [ "$(calls)" = "$(all_three)" ]
  [ "$(jq '.ladder.picks | length' "$record_file")" -eq 0 ]
}

@test "a broken form goes to the operator with the check's reason" {
  answer_for reader '{"asks_operator":true,"question":"Five or ten?","options":["five","ten"],"recommended":"seven","claims_done":false,"closes_round":false,"guidance_answer":"","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}'
  run_gate
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_recommended_outside_note seven)")" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
}

@test "an option marked as recommended goes to the operator as a broken form, and nothing more is asked" {
  answer_for reader "$(rung_form ten '["five (recommended)","ten"]')"
  run_gate
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_marked_option_note "five (recommended)")")" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
}

@test "a model out of time, or refused, goes to the operator with the reason" {
  status_for checker 124
  run_gate
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_model_timeout_note "$CHECKER_MODEL" "$CHECKER_SECONDS")")" ]
  rm "$FAKE_ANSWERS/checker.status"
  status_for sorter 3
  run_gate
  [ "$(message)" = "$(gate_broken_note "$(refuse_model_exit_note "$SORTER_MODEL" 3)")" ]
}

@test "a checker naming an entry it was not handed goes to the operator" {
  answer_for checker '{"breaks":[{"entry":"made-up.md","why":"No."}],"miscalled":[],"explains_code":false}'
  run_gate
  [ "$(message)" = "$(gate_broken_note "$(refuse_unknown_entry_note made-up.md)")" ]
}

@test "a kind whose header holds no route the gate knows goes to the operator" {
  kind defaults maybe
  run_gate
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_kind_route_note defaults maybe "ask, ladder, go, accept, light")")" ]
}

@test "a question sent back three times in a row goes to the operator on the fourth" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"closes_round":false,"guidance_answer":"","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}'
  run_gate false
  run_gate true
  run_gate true
  [ "$(reason)" = "$(gate_no_recommendation_note)" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  run_gate true
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_loop_line 3 "$(gate_no_recommendation_note)")")" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 0 ]
}

@test "the loop guard reached through the checker brings the operator the question in that stop, the summary after the checker" {
  answer_for checker '{"breaks":[],"miscalled":[],"explains_code":true}'
  run_gate false
  run_gate true
  run_gate true
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  rm "$FAKE_CALLS"
  run_gate true
  answered_operator
  [ "$(calls)" = "reader $READER_MODEL"$'\n'"checker $CHECKER_MODEL"$'\n'"summary $SUMMARY_MODEL" ]
  sendback="$(gate_checker_sendback_note "$(gate_explains_code_line)"$'\n')"
  [ "$(message)" = "$(operator_message "$(gate_loop_line 3 "$sendback")")" ]
}

@test "a new turn of the operator's starts the count again" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"closes_round":false,"guidance_answer":"","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}'
  run_gate false
  run_gate true
  run_gate true
  run_gate false
  [ "$(reason)" = "$(gate_no_recommendation_note)" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 1 ]
}

@test "a part of the gate that will not load lets the reply stop, saying so" {
  kit="$BATS_TEST_TMPDIR/kit"
  mkdir -p "$kit"
  cp -r "$BATS_TEST_DIRNAME/../../lib" "$BATS_TEST_DIRNAME/../../stand-in" "$kit/"
  rm "$kit/stand-in/lib/checker.sh"
  run --separate-stderr "$kit/stand-in/hooks/gate.sh" <<<"$(stop_event "$session" "$reply" false)"
  [ "$status" -eq 0 ]
  opening="$(gate_broken_note why)"
  [[ "$(message)" == "${opening%%$'\n'*}"* ]]
  [[ "$(message)" == *"checker.sh"* ]]
  rm "$kit/stand-in/lib/words.sh"
  run --separate-stderr "$kit/stand-in/hooks/gate.sh" <<<"$(stop_event "$session" "$reply" false)"
  [ "$status" -eq 0 ]
  [[ "$(message)" == "Stand-in: a part of the gate could not be loaded"* ]]
}

@test "an event that cannot be read, or names no session, lets the reply stop, saying so" {
  run --separate-stderr "$gate" <<<"not json"
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_event_unreadable_note)")" ]
  run --separate-stderr "$gate" <<<'{"session_id":"../escape","last_assistant_message":"Hi."}'
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_event_session_note)")" ]
  [ -z "$(calls)" ]
}

@test "a record that cannot be written lets the reply stop, saying so" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"closes_round":false,"guidance_answer":"","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}'
  mkdir -p "$history/sessions"
  chmod a-w "$history/sessions"
  run_gate
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_state_unwritable_note "$history/sessions")")" ]
}

@test "a record that is not one the gate wrote is refused, never read as empty" {
  mkdir -p "$history/sessions"
  printf '{"sent_back":"many"}\n' >"$record_file"
  run_gate
  [ "$(message)" = "$(gate_broken_note "$(refuse_state_unreadable_note "$record_file")")" ]
}

@test "the jobs together fit inside the time limit the gate is registered with, every stop to the operator counted whole" {
  [ "$(derive_jobs_seconds)" -lt "$GATE_HOOK_SECONDS" ]
  # A stop that brings a question to the operator runs the summary and writes
  # the log's line beside the jobs before them: the question's first stop, and
  # an answer that moved again, beside the reading.
  first=$(($(derive_stop_seconds "$READER_SECONDS" "$CHECKER_SECONDS" "$SORTER_SECONDS" "$SUMMARY_SECONDS") + LOG_LOCK_SECONDS))
  moved=$(($(derive_stop_seconds "$MATCHER_SECONDS" "$READING_SECONDS" "$SUMMARY_SECONDS") + LOG_LOCK_SECONDS))
  [ "$(derive_jobs_seconds)" -ge "$first" ]
  [ "$(derive_jobs_seconds)" -ge "$moved" ]
}

# The question log's lines, one JSON object a line.
log_file() { printf '%s/log/questions.jsonl' "$history"; }

@test "a question let go leaves one whole log line: as asked, why, its sort and checks, the exchange and the summary" {
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate
  answered_operator
  [ "$(wc -l <"$(log_file)")" -eq 1 ]
  line="$(cat "$(log_file)")"
  [ "$(jq -c '{number, session, briefs, question, kind, unsure, risks, checks, ladder, outcome, reasons, approved, summary, reading, answer}' <<<"$line")" = \
    "$(jq -cn --arg session "$session" --arg why "$(gate_kind_line naming "The naming kind.")" \
      --argjson summary "$(summary_form)" --argjson check "$(clean_check)" \
      '{number: 1, session: $session, briefs: null, question: "Five retries or ten?", kind: "naming",
        unsure: false, risks: [], checks: [$check], ladder: null, outcome: "to-operator", reasons: [$why], approved: "",
        summary: $summary, reading: null, answer: ""}')" ]
  # No retelling is asked for, so none is kept.
  [ "$(jq 'has("retold")' <<<"$line")" = false ]
  [ "$(jq -c '[.exchange[] | .text]' <<<"$line")" = "$(jq -cn --arg a "$reply" '[$a]')" ]
  jq -e '.id | test("^[0-9a-f]{16}$")' <<<"$line"
  jq -e '.when | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' <<<"$line"
}

@test "an answer that held is logged as would have been approved, with every rung's pick, and the brief the session holds" {
  mkdir -p "$project/aidk-plans" "$project/aidk-organizer/taken"
  printf -- '---\nsummary: Trash.\nafter: []\ntouches: [aidk-plans]\ncreates: []\n---\n\n# file-trash\n' >"$project/aidk-plans/file-trash.md"
  printf 'session: %s\nsince: 2026-10-06T09:00:00Z\n' "$session" >"$project/aidk-organizer/taken/file-trash"
  climb "$(item five)" "$(item five)"
  answered_operator
  line="$(cat "$(log_file)")"
  [ "$(jq -c '{briefs, kind, outcome, approved, ladder}' <<<"$line")" = \
    "$(jq -cn --argjson pick "$(item five)" '{briefs: ["file-trash"], kind: "defaults", outcome: "would-have-approved",
      approved: "five", ladder: {first: {options: ["five", "ten"], recommended: "five"}, picks: [$pick, $pick]}}')" ]
}

@test "the cold reading is logged in its own words" {
  answer_for reading '{"reading":"Ten is safer."}'
  climb "$(item ten)" "$(item five)" "$(item five)" "$(item ten)"
  answered_operator
  [ "$(jq -r '.reading' "$(log_file)")" = "Ten is safer." ]
}

@test "a log that cannot be written never holds the question up: the operator is told under it" {
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  mkdir -p "$history/log"
  chmod a-w "$history/log"
  run_gate
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_kind_line naming "The naming kind.")")"$'\n'"$(gate_log_failed_line "$(refuse_log_unwritable_note "$history/log")")" ]
}

@test "a broken gate holding a question logs it, marked with why" {
  run_gate
  status_for matcher 124
  run_gate true
  broken="$(gate_broken_note "$(refuse_model_timeout_note "$MATCHER_MODEL" "$MATCHER_SECONDS")")"
  [ "$(message)" = "$broken" ]
  [ "$(jq -c '{question, outcome, reasons, summary}' "$(log_file)")" = \
    "$(jq -cn --arg broken "$broken" '{question: "Five retries or ten?", outcome: "to-operator", reasons: ($broken | split("\n") | map(select(. != ""))), summary: null}')" ]
}

@test "a broken gate holding no question logs nothing" {
  status_for reader 124
  run_gate
  [ "$(message)" = "$(gate_broken_note "$(refuse_model_timeout_note "$READER_MODEL" "$READER_SECONDS")")" ]
  [ ! -e "$(log_file)" ]
}

# --- The step go.

# The suite's session holding a brief through the work organizer, as its take
# leaves it.
hold_brief() {
  mkdir -p "$project/aidk-plans" "$project/aidk-organizer/taken"
  printf -- '---\nsummary: Trash.\nafter: []\ntouches: [aidk-plans]\ncreates: []\n---\n\n# file-trash\n' >"$project/aidk-plans/file-trash.md"
  printf 'session: %s\nsince: 2026-10-06T09:00:00Z\n' "$session" >"$project/aidk-organizer/taken/file-trash"
}

# A step's report, read as the step form given, labelled by the sorter as
# given, in a session holding a brief, with a kind for the step go; the
# decision it puts is left in step_question.
step_report() {
  step_question="$(gate_step_question "step 9, the round list")"
  kind step-go go
  hold_brief
  answer_for reader "${1:-$(step_form)}"
  answer_for step-sorter "${2:-$clean_step_sort}"
}

clean_step_sort='{"majors":[],"unsure":false}'
step_reply="Step 8 is built and its proof passed. Next is step 9, the round list."

# The note the operator is shown for a go the stand-in would give, given why
# it came to them, then the problems fixed in passing.
go_message() {
  gate_step_trial_note "$step_question" "$1"
  shift
  [ "$#" -gt 0 ] || return 0
  printf '\n'
  gate_fixed_heading
  for problem in "$@"; do gate_problem_line "$problem"; done
}

# The same note during the trial, the problems fixed in passing given.
trial_message() {
  go_message "$(gate_trial_line step-go)" "$@"
}

# The note the operator is shown for a report whose go is theirs, given why.
step_operator_message() {
  gate_step_operator_note "$step_question" "$1"
}

@test "a clean step's report: during the trial the reply stops, the operator told the stand-in would have said go, and it is logged so" {
  . "$lib/step-go.sh"
  step_report
  run_gate false "$step_reply"
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(trial_message)" ]
  [ "$(calls)" = "reader $READER_MODEL"$'\n'"step-sorter $SORTER_MODEL" ]
  grep -qF -- "$step_reply" "$FAKE_PROMPT.step-sorter"
  grep -qF -- "lost-data: $(step_lost_data_words)" "$FAKE_PROMPT.step-sorter"
  grep -qF -- "workaround: The workaround risk." "$FAKE_PROMPT.step-sorter"
  line="$(cat "$(log_file)")"
  [ "$(jq -c '{question, kind, outcome, approved, reasons, briefs}' <<<"$line")" = \
    "$(jq -cn --arg q "$step_question" --arg why "$(gate_trial_line step-go)" \
      '{question: $q, kind: "step-go", outcome: "would-have-approved", approved: "go", reasons: [$why], briefs: ["file-trash"]}')" ]
  [ "$(jq -c '.step' <<<"$line")" = "$(jq -c '{problems, proof, next_step, next_step_number, next_step_from, next_step_marks} + {majors: [], unsure: false}' <<<"$(step_form)")" ]
  [ "$(jq -c '[.exchange[] | .text]' <<<"$line")" = "$(jq -cn --arg a "$step_reply" '[$a]')" ]
  [ ! -s "$record_file" ] || [ "$(jq -c . "$record_file")" = "$EMPTY_RECORD" ]
}

@test "a step whose problems were all fixed: the go it would give lists them as fixed in passing" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.problems = [{problem: "a typo in a refusal", state: "fixed"}, {problem: "a stale comment", state: "fixed"}]')"
  run_gate false "$step_reply"
  [ "$(message)" = "$(trial_message "a typo in a refusal" "a stale comment")" ]
  [ "$(jq -c '[.step.problems[] | .state]' "$(log_file)")" = '["fixed","fixed"]' ]
}

@test "an unfixed problem needing no decision is sent back to be fixed, and the report is read again" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.problems = [{problem: "the budget test is red", state: "unfixed"}, {problem: "a typo", state: "fixed"}]')"
  run_gate false "$step_reply"
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(gate_fix_first_note; gate_problem_line "the budget test is red")" ]
  [[ "$(reason)" == "From the stand-in: fix this before the next step."* ]]
  [ "$(jq '.sent_back' "$record_file")" -eq 1 ]
  [ ! -e "$(log_file)" ]
  answer_for reader "$(step_form '.problems = [{problem: "the budget test is red", state: "fixed"}, {problem: "a typo", state: "fixed"}]')"
  rm "$FAKE_CALLS"
  run_gate true "Fixed: the budget test is green. Step 8 is done; next is step 9, the round list."
  [ "$(calls)" = "reader $READER_MODEL"$'\n'"step-sorter $SORTER_MODEL" ]
  [ "$(message)" = "$(trial_message "the budget test is red" "a typo")" ]
  [ "$(jq -c '[.exchange[] | .from]' "$(log_file)")" = '["agent","stand-in","agent"]' ]
}

@test "an unfixed problem needing a decision is sent back to be asked, and the question goes through the gate" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.problems = [{problem: "which name the new file takes", state: "needs-decision"}]')"
  run_gate false "$step_reply"
  [ "$(reason)" = "$(gate_ask_first_note; gate_problem_line "which name the new file takes")" ]
  answer_for reader "$(whole_form)"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  rm "$FAKE_CALLS"
  run_gate true
  answered_operator
  [ "$(calls)" = "$(all_three)"$'\n'"summary $SUMMARY_MODEL" ]
  [ "$(message)" = "$(operator_message "$(gate_kind_line naming "The naming kind.")")" ]
}

@test "unfixed problems of both sorts are sent back together, the fixing first" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.problems = [{problem: "which name", state: "needs-decision"}, {problem: "red test", state: "unfixed"}]')"
  run_gate false "$step_reply"
  [ "$(reason)" = "$(gate_fix_first_note; gate_problem_line "red test"; gate_ask_first_heading; gate_problem_line "which name")" ]
}

@test "a major problem already fixed goes to the operator, never sent back and never a go" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.problems = [{problem: "the old rows were dropped", state: "fixed"}]')" \
    '{"majors":[{"problem":"the old rows were dropped","label":"lost-data"}],"unsure":false}'
  run_gate false "$step_reply"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(step_operator_message "$(gate_major_line "the old rows were dropped" lost-data "$(step_lost_data_words)")")" ]
  [ "$(jq -c '{outcome, approved}' "$(log_file)")" = '{"outcome":"to-operator","approved":""}' ]
}

@test "a major problem left unfixed, or one carrying a preset risk, goes to the operator before any send-back" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.problems = [{problem: "a test now fails", state: "unfixed"}]')" \
    '{"majors":[{"problem":"a test now fails","label":"broken-check"},{"problem":"a guard skipped","label":"workaround"}],"unsure":false}'
  run_gate false "$step_reply"
  why="$(gate_major_line "a test now fails" broken-check "$(step_broken_check_words)")"$'\n'
  why+="$(gate_major_line "a guard skipped" workaround "The workaround risk.")"
  [ "$(message)" = "$(step_operator_message "$why")" ]
}

@test "a sorter unsure whether a problem is major counts it as major" {
  . "$lib/step-go.sh"
  step_report "$(step_form)" '{"majors":[],"unsure":true}'
  run_gate false "$step_reply"
  [ "$(message)" = "$(step_operator_message "$(gate_major_unsure_line)")" ]
}

@test "a failed proof, or one the report does not mention, goes to the operator" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.proof = "failed"')"
  run_gate false "$step_reply"
  [ "$(message)" = "$(step_operator_message "$(gate_proof_failed_line)")" ]
  answer_for reader "$(step_form '.proof = ""')"
  run_gate false "$step_reply"
  [ "$(message)" = "$(step_operator_message "$(gate_proof_unsaid_line)")" ]
}

@test "the brief's first step is the operator's, as is a next step not numbered" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.next_step_number = 1')"
  run_gate false "$step_reply"
  [ "$(message)" = "$(step_operator_message "$(gate_first_step_line)")" ]
  answer_for reader "$(step_form '.next_step_number = 0')"
  run_gate false "$step_reply"
  [ "$(message)" = "$(step_operator_message "$(gate_step_number_unsaid_line)")" ]
}

@test "a next step the brief runs alone at a quiet moment is the operator's" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.next_step_marks = ["runs-alone"]')"
  run_gate false "$step_reply"
  [ "$(message)" = "$(step_operator_message "$(gate_step_mark_line "$(step_mark_words runs-alone)")")" ]
}

@test "a next step that pushes, syncs, deletes or touches another session's work is the operator's, each said" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.next_step_marks = ["pushes", "deletes", "pushes"]')"
  run_gate false "$step_reply"
  why="$(gate_step_mark_line "$(step_mark_words deletes)")"$'\n'"$(gate_step_mark_line "$(step_mark_words pushes)")"
  [ "$(message)" = "$(step_operator_message "$why")" ]
  answer_for reader "$(step_form '.next_step_marks = ["syncs", "other-session"]')"
  run_gate false "$step_reply"
  why="$(gate_step_mark_line "$(step_mark_words other-session)")"$'\n'"$(gate_step_mark_line "$(step_mark_words syncs)")"
  [ "$(message)" = "$(step_operator_message "$why")" ]
}

# regression: a session holding no brief was read as holding one named null,
# so its step was weighed as the brief's own and a go was given.
@test "new work next, or a session holding no brief, is the operator's" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.next_step_from = "new-work"')"
  run_gate false "$step_reply"
  [ "$(message)" = "$(step_operator_message "$(gate_new_work_line)")" ]
  rm "$project/aidk-organizer/taken/file-trash"
  answer_for reader "$(step_form)"
  run_gate false "$step_reply"
  [ "$(message)" = "$(step_operator_message "$(gate_no_brief_line)")" ]
  [ "$(tail -n 1 "$(log_file)" | jq -c '.briefs')" = '[]' ]
  rm -r "$project/aidk-plans"
  run_gate false "$step_reply"
  [ "$(message)" = "$(step_operator_message "$(gate_briefs_unknown_line)")" ]
}

@test "a broken or unsure reading of a step's report goes to the operator, and nothing is said go" {
  . "$lib/step-go.sh"
  step_report
  status_for step-sorter 124
  run_gate false "$step_reply"
  [ "$(message)" = "$(gate_broken_note "$(refuse_model_timeout_note "$SORTER_MODEL" "$SORTER_SECONDS")")" ]
  rm "$FAKE_ANSWERS/step-sorter.status"
  answer_for step-sorter '{"majors":[{"problem":"rows gone","label":"data-loss"}],"unsure":false}'
  run_gate false "$step_reply"
  [ "$(message)" = "$(gate_broken_note "$(refuse_unknown_label_note data-loss)")" ]
  answer_for reader "$(step_form '.ends_step = false')"
  run_gate false "$step_reply"
  [ "$(message)" = "$(gate_broken_note "$(refuse_no_step_but_note)")" ]
  [ ! -e "$(log_file)" ]
}

@test "a step sent back as often as it may be goes to the operator, with what would have been sent" {
  . "$lib/step-go.sh"
  step_report "$(step_form '.problems = [{problem: "red test", state: "unfixed"}]')"
  run_gate false "$step_reply"
  run_gate true "$step_reply"
  run_gate true "$step_reply"
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  run_gate true "$step_reply"
  words="$(gate_fix_first_note; gate_problem_line "red test")"
  [ "$(message)" = "$(step_operator_message "$(gate_loop_line "$SEND_BACK_LIMIT" "$words")")" ]
  [ "$(jq '.exchange | length' "$(log_file)")" -eq 7 ]
}

@test "a preset with no kind for the step go lets the report stop as it is" {
  hold_brief
  answer_for reader "$(step_form)"
  run_gate false "$step_reply"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
}

@test "a preset with two kinds for the step go goes to the operator" {
  step_report
  kind step-done go
  run_gate false "$step_reply"
  [ "$(message)" = "$(gate_broken_note "$(refuse_go_kind_twice_note go "$preset_dir/questions")")" ]
}

# regression: the collection reader read a kinds folder it could not list as
# holding no kinds, so the gate found no kind for the step go and let every
# step's report stop unweighed, as a project wanting no step go.
@test "a kinds folder that cannot be listed brings a step's report to the operator with why, never lets it pass" {
  . "$BATS_TEST_DIRNAME/../../lib/readers/collection.sh"
  step_report
  chmod 000 "$preset_dir/questions"
  run_gate false "$step_reply"
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(collection_unreadable_note "$preset_dir/questions")")" ]
}

@test "a question sorted as a step's report goes to the operator: a reply that asks is never said go to" {
  kind step-go go
  answer_for sorter '{"kind":"step-go","unsure":false,"risks":[],"defers":false}'
  run_gate
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_go_kind_line step-go)")" ]
}

# The kinds given through the trial, as the operator's yes leaves them: a yes
# file each in the project's stand-in folder, given before anything the suite
# settles. The kit, for the skill hook, is the suite's own.
trusted_since="2026-01-01T00:00:00Z"
switch_kinds() {
  local kind
  . "$lib/trial.sh"
  for kind in "$@"; do write_trust_file "$history" "$kind" "$trusted_since"; done
  kit="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# The skill hook of the kit given, run on the skill and words given, in the
# suite's session.
run_skill() {
  jq -cn --arg skill "$2" --arg args "$3" --arg session "$session" \
    '{session_id: $session, tool_name: "Skill", tool_input: {skill: $skill, args: $args}}' \
    | "$1/stand-in/hooks/skill-hook.sh"
}

@test "once its kind is switched, a clean step's report is told go, logged as settled, listed and reopened" {
  . "$lib/step-go.sh"
  . "$lib/reopen.sh"
  switch_kinds step-go
  step_report "$(step_form '.problems = [{problem: "a typo in a refusal", state: "fixed"}]')"
  run_gate false "$step_reply"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "From the stand-in: go." ]
  line="$(cat "$(log_file)")"
  [ "$(jq -c '{number, question, kind, outcome, approved, reasons}' <<<"$line")" = \
    "$(jq -cn --arg q "$step_question" '{number: 1, question: $q, kind: "step-go", outcome: "settled", approved: "go", reasons: []}')" ]
  shown="$(run_skill "$kit" devkit-stand-in-settled all | jq -r '.systemMessage')"
  grep -qxF -- "$(settled_item_line 1 "$step_question")" <<<"$shown"
  grep -qF -- "Settled on: go," <<<"$shown"
  answer="$(run_skill "$kit" devkit-stand-in-reopen 1)"
  shown="$(jq -r '.systemMessage' <<<"$answer")"
  grep -qxF -- "$(reopen_question_line "$step_question")" <<<"$shown"
  grep -qxF -- "$(reopen_fixed_heading)" <<<"$shown"
  grep -qxF -- "$(gate_problem_line "a typo in a refusal")" <<<"$shown"
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$answer")" = "$(reopen_go_agent_note 1 "$step_question")" ]
}

@test "once switched, a go that cannot be logged is never given: it goes to the operator, saying why" {
  . "$lib/step-go.sh"
  switch_kinds step-go
  step_report
  mkdir -p "$history/log"
  chmod a-w "$history/log"
  run_gate false "$step_reply"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(go_message "$(gate_log_failed_line "$(refuse_log_unwritable_note "$history/log")")")" ]
}

# --- The round's decisions, laid out before building.

# The reader's form of a reply that closes the round and asks to build.
round_form() {
  jq -c '.asks_operator = false | .question = "" | .options = [] | .recommended = "" | .closes_round = true' <<<"$(whole_form)"
}
round_reply="That was the last question. Shall I start building step 1?"

# The log line given, answered as given.
answered() { jq -c --arg answer "$2" '.answer = $answer' <<<"$1"; }

# A request to build as the log keeps it, by number, session and the
# decisions it laid out, as a JSON array.
round_line() {
  jq -c --argjson round "$3" --arg q "$(gate_round_question)" \
    '.question = $q | .retold = null | .ladder = null | .summary = null | .round = $round' \
    <<<"$(log_line "$1" "$OUTCOME_TO_OPERATOR" "$2" 2026-10-06T08:00:00Z)"
}

# The suite session's log: an earlier round, closed by a request to build and
# a step built after it; then this round's three decisions — the operator's
# answer, the stand-in's settling, and one it would have approved that the
# operator answered — with another session's question among them.
round_log() {
  add_log_lines "$history" \
    "$(answered "$(log_line 1 "$OUTCOME_TO_OPERATOR" "$session" 2026-10-06T07:00:00Z)" "five")" \
    "$(round_line 2 "$session" '[{"number":1,"by":"operator","decision":"Five tries."}]')" \
    "$(jq -c '.step = {} | .approved = "go"' <<<"$(log_line 3 "$OUTCOME_WOULD_HAVE_APPROVED" "$session" 2026-10-06T08:30:00Z go)")" \
    "$(answered "$(log_line 4 "$OUTCOME_TO_OPERATOR" "$session" 2026-10-06T09:00:00Z)" "Ten, to be safe.")" \
    "$(log_line 5 "$OUTCOME_SETTLED" session-2 2026-10-06T09:05:00Z)" \
    "$(log_line 6 "$OUTCOME_SETTLED" "$session" 2026-10-06T09:10:00Z five)" \
    "$(answered "$(log_line 7 "$OUTCOME_WOULD_HAVE_APPROVED" "$session" 2026-10-06T09:20:00Z five)" "yes")"
}

round_answer='{"decisions":[{"number":4,"decision":"A failed call is tried ten times, not five."},{"number":6,"decision":"The retry waits 5 seconds, not 10."},{"number":7,"decision":"Old rows are kept for five days."}]}'

# The operator's message for this round, as the round reader wrote it.
round_message() {
  round_heading
  round_item_line 4 "$(round_by_operator_words)" "A failed call is tried ten times, not five."
  round_item_line 6 "$(round_by_stand_in_words)" "The retry waits 5 seconds, not 10."
  round_item_line 7 "$(round_by_operator_words)" "Old rows are kept for five days."
  round_hint
}

@test "a closed round shows every decision of the round, the operator's and the stand-in's, each marked and numbered" {
  round_log
  answer_for reader "$(round_form)"
  answer_for round "$round_answer"
  run_gate false "$round_reply"
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(round_message)" ]
  [ "$(calls)" = "reader $READER_MODEL"$'\n'"round $ROUND_MODEL" ]
  # The round reader is handed the round's decisions alone, by their log
  # numbers, with who decided each and what was answered or settled on.
  prompt="$FAKE_PROMPT.round"
  [ "$(grep -c '^=====DECISION ' "$prompt")" -eq 3 ]
  grep -qxF "=====DECISION 4=====" "$prompt"
  grep -qxF "Question: Should a call be tried five or ten times? (4)" "$prompt"
  grep -qxF "$(round_by_operator_prompt_words "Ten, to be safe.")" "$prompt"
  grep -qxF "$(round_by_stand_in_prompt_words five)" "$prompt"
  grep -qxF "The agent recommended: Five tries." "$prompt"
  grep -qF -- '"enum":[4,6,7]' "$FAKE_ARGS.round"
  # The request is logged with the list as the operator was shown it.
  line="$(tail -n 1 "$(log_file)")"
  [ "$(jq -c '{number, question, outcome, kind, approved, answer}' <<<"$line")" = \
    "$(jq -cn --arg q "$(gate_round_question)" '{number: 8, question: $q, outcome: "to-operator", kind: null, approved: "", answer: ""}')" ]
  [ "$(jq -c '[.round[] | [.number, .by]]' <<<"$line")" = '[[4,"operator"],[6,"stand-in"],[7,"operator"]]' ]
  [ "$(jq -c '[.exchange[] | .text]' <<<"$line")" = "$(jq -cn --arg a "$round_reply" '[$a]')" ]
}

@test "a round reader that fails never holds the request up: each decision is shown as the log keeps it, saying why" {
  round_log
  answer_for reader "$(round_form)"
  answer_for round '{"decisions":[{"number":4,"decision":"Ten."}]}'
  run_gate false "$round_reply"
  why="$(refuse_decision_missing_note 6; refuse_decision_missing_note 7)"
  expected="$(round_heading
    round_failed_note "$why"
    round_item_line 4 "$(round_by_operator_words)" "$(round_answered_words "Should a call be tried five or ten times? (4)" "Ten, to be safe.")"
    round_item_line 6 "$(round_by_stand_in_words)" "$(round_settled_words "Should a call be tried five or ten times? (6)" five)"
    round_item_line 7 "$(round_by_operator_words)" "$(round_answered_words "Should a call be tried five or ten times? (7)" yes)"
    round_hint)"
  [ "$(message)" = "$expected" ]
}

@test "a round with no decision since the last request asks no model, and says so" {
  add_log_lines "$history" "$(round_line 1 "$session" '[]')"
  answer_for reader "$(round_form)"
  run_gate false "$round_reply"
  [ "$(message)" = "$(round_heading; round_empty_line; round_hint)" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
  [ "$(tail -n 1 "$(log_file)" | jq -c '.round')" = '[]' ]
}

@test "a reply asking a question beside the request to build is taken as the question first" {
  answer_for reader "$(jq -c '.closes_round = true' <<<"$(whole_form)")"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate
  answered_operator
  [ "$(calls)" = "$(all_three)"$'\n'"summary $SUMMARY_MODEL" ]
  [ "$(message)" = "$(operator_message "$(gate_kind_line naming "The naming kind.")")" ]
}

@test "\"reopen N\" brings one back and building waits: the reopened decision is laid out anew before building" {
  round_log
  answer_for reader "$(round_form)"
  answer_for round "$round_answer"
  run_gate false "$round_reply"
  kit="$BATS_TEST_DIRNAME/../.."
  # The operator's own decision, laid out in the list, is reopened in full,
  # and the agent is told building waits.
  answer="$(run_skill "$kit" devkit-stand-in-reopen 4)"
  shown="$(jq -r '.systemMessage' <<<"$answer")"
  [ "$(head -n 1 <<<"$shown")" = "$(reopen_decided_heading 4 when where | head -n 1)" ]
  grep -qxF -- "$(reopen_question_line "Should a call be tried five or ten times? (4)")" <<<"$shown"
  grep -qxF -- "$(reopen_answered_line "Ten, to be safe.")" <<<"$shown"
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$answer")" = \
    "$(reopen_decided_agent_note 4 "Five retries or ten? (4)" "five${LADDER_OPTION_SEPARATOR}ten" "Ten, to be safe."; reopen_round_waits_note)" ]
  # The stand-in's own settling in the list is reopened too, building waiting.
  answer="$(run_skill "$kit" devkit-stand-in-reopen 6)"
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$answer")" = \
    "$(reopen_agent_note 6 "Five retries or ten? (6)" "five${LADDER_OPTION_SEPARATOR}ten" five; reopen_round_waits_note)" ]
  # The agent asks it again, and it reaches the operator, marked reopened.
  answer_for reader "$(whole_form)"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate false
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_reopened_line 4)")" ]
  # Asked to build again, the operator sees the decision taken anew alone:
  # what they did not reopen was laid out already, and stands.
  answer_for reader "$(round_form)"
  answer_for round '{"decisions":[{"number":9,"decision":"A failed call is tried five times."}]}'
  run_gate false "$round_reply"
  [ "$(message)" = "$(round_heading; round_item_line 9 "$(round_by_operator_words)" "A failed call is tried five times."; round_hint)" ]
}

@test "\"go\" starts the first step: it is kept as the request's answer, and the round's decisions are not laid out again" {
  round_log
  answer_for reader "$(round_form)"
  answer_for round "$round_answer"
  run_gate false "$round_reply"
  [[ "$(message)" == *"$(round_hint)" ]]
  run "$BATS_TEST_DIRNAME/../hooks/answer-hook.sh" <<<"$(jq -cn --arg s "$session" '{session_id: $s, hook_event_name: "UserPromptSubmit", prompt: "go"}')"
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$(log_file)" | jq -c '{number, answer}')" = '{"number":8,"answer":"go"}' ]
  rm "$FAKE_CALLS"
  run_gate false "$round_reply"
  [ "$(message)" = "$(round_heading; round_empty_line; round_hint)" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
}

@test "a number neither settled nor laid out in a round still cannot be reopened" {
  round_log
  answer_for reader "$(round_form)"
  answer_for round "$round_answer"
  run_gate false "$round_reply"
  shown="$(run_skill "$BATS_TEST_DIRNAME/../.." devkit-stand-in-reopen 8 | jq -r '.systemMessage')"
  [ "$shown" = "$(reopen_unknown_note 8)" ]
}

# --- Kinds accepted as they stand, and kinds given one challenge. Sorting is
# the sorter's job, so each case gives the sort and proves the route.

# The sorter's answer naming the kind given, putting work off where the
# second word is "defers".
sorted() {
  jq -cn --arg kind "$1" --argjson defers "$([ "${2:-}" = defers ] && echo true || echo false)" \
    '{kind: $kind, unsure: false, risks: [], defers: $defers}'
}

# A reader's form asking the question given, recommending the first of the
# two options given.
asking() {
  jq -cn --arg q "$1" --arg a "$2" --arg b "$3" \
    '{asks_operator: true, question: $q, options: [$a, $b], recommended: $a, claims_done: false,
      closes_round: false, guidance_answer: "", ends_step: false, problems: [], proof: "", next_step: "",
      next_step_number: 0, next_step_from: "", next_step_marks: []}'
}

# The operator's message for a recommendation the stand-in would have
# accepted, given the question as asked, the label and why it came to them.
accepted_message() {
  printf '%s\n%s' "$(gate_accepted_note "$1" "$2" "$3")" "$(story)"
}

@test "\"Shall I push?\" and \"fix here or in a new session?\", sorted as organising the work, reach the operator with no ladder" {
  kind organising-the-work ask
  for question in "Shall I push?" "Fix it here or in a new session?"; do
    rm -f "$FAKE_CALLS" "$record_file"
    answer_for reader "$(asking "$question" here "a new session")"
    answer_for sorter "$(sorted organising-the-work)"
    run_gate
    answered_operator
    [ "$(calls)" = "$(all_three)"$'\n'"summary $SUMMARY_MODEL" ]
    [ "$(tail -n 1 "$(log_file)" | jq -c '.ladder')" = null ]
    [ "$(message)" = "$(operator_message_for "$question" "$(gate_kind_line organising-the-work "The organising-the-work kind.")")" ]
  done
}

@test "\"which step first?\" and \"fold step 4 into step 3?\", sorted as step timing, are never challenged: on trial they reach the operator as what would have been accepted" {
  kind step-timing accept
  for question in "Which step first, 3 or 4?" "Fold step 4 into step 3?"; do
    rm -f "$FAKE_CALLS"
    answer_for reader "$(asking "$question" "step 3 first" "step 4 first")"
    answer_for sorter "$(sorted step-timing)"
    run_gate
    answered_operator
    [ "$(calls)" = "$(all_three)"$'\n'"summary $SUMMARY_MODEL" ]
    [ "$(message)" = "$(accepted_message "$question" "step 3 first" "$(gate_trial_line step-timing)")" ]
    [ "$(tail -n 1 "$(log_file)" | jq -c '{question, kind, outcome, approved, ladder}')" = \
      "$(jq -cn --arg q "$question" '{question: $q, kind: "step-timing", outcome: "would-have-approved", approved: "step 3 first", ladder: null}')" ]
  done
}

@test "once through the trial, step timing stands with no challenge: the agent goes on, and it is logged as settled and listed" {
  . "$lib/reopen.sh"
  switch_kinds step-timing
  kind step-timing accept
  question="Fold step 4 into step 3?"
  answer_for reader "$(asking "$question" yes no)"
  answer_for sorter "$(sorted step-timing)"
  run_gate
  [ "$status" -eq 0 ]
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(gate_settled_note yes)" ]
  [ "$(calls)" = "$(all_three)" ]
  [ "$(jq -c '{number, question, kind, outcome, approved, reasons, summary}' "$(log_file)")" = \
    "$(jq -cn --arg q "$question" '{number: 1, question: $q, kind: "step-timing", outcome: "settled", approved: "yes", reasons: [], summary: null}')" ]
  [ "$(jq 'has("retold")' "$(log_file)")" = false ]
  [ "$(jq -c '[.exchange[] | .text]' "$(log_file)")" = "$(jq -cn --arg a "$reply" '[$a]')" ]
  [ ! -s "$record_file" ] || [ "$(jq -c . "$record_file")" = "$EMPTY_RECORD" ]
  shown="$(run_skill "$kit" devkit-stand-in-settled all | jq -r '.systemMessage')"
  grep -qxF -- "$(settled_item_line 1 "$question")" <<<"$shown"
}

@test "a reopened decision asked again reaches the operator under a switched kind, whatever its route, and only once" {
  . "$lib/reopen.sh"
  switch_kinds step-timing
  kind step-timing accept
  question="Fold step 4 into step 3?"
  answer_for reader "$(asking "$question" yes no)"
  answer_for sorter "$(sorted step-timing)"
  # Settled without the operator once its kind is switched, and reopened.
  run_gate
  [ "$(reason)" = "$(gate_settled_note yes)" ]
  answer="$(run_skill "$kit" devkit-stand-in-reopen 1)"
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$answer")" = "$(reopen_agent_note 1 "$question" "" yes)" ]
  # regression: a question its kind accepted keeps no options in the log, and
  # its note told the agent "Its options: ." The note is the one with options,
  # their sentence and nothing else left out.
  with="$(reopen_agent_note 1 "$question" yes yes)"
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$answer")" = "${with/"$(reopen_options_sentence yes)"/}" ]
  [ "$(jq -c '.reopened' "$record_file")" = '[1]' ]
  # Asked again, it reaches the operator, saying they reopened it, and is
  # logged as theirs.
  rm "$FAKE_CALLS"
  run_gate false
  answered_operator
  [ "$(calls)" = "$(all_three)"$'\n'"summary $SUMMARY_MODEL" ]
  [ "$(jq -c '.reopened' "$record_file")" = null ]
  [ "$(message)" = "$(operator_message_for "$question" "$(gate_reopened_line 1)")" ]
  [ "$(last_line | jq -c '{number, kind, outcome, approved, reasons}')" = \
    "$(jq -cn --arg why "$(gate_reopened_line 1)" '{number: 2, kind: "step-timing", outcome: "to-operator", approved: "", reasons: [$why]}')" ]
  # The mark is spent: the next question of the kind is settled again.
  answer_for reader "$(asking "$question" yes no)"
  run_gate false
  [ "$(reason)" = "$(gate_settled_note yes)" ]
}

@test "a reopened decision is never challenged away: a kind with a challenge reaches the operator at once" {
  kind naming ask "Do we really need it?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  mkdir -p "$(dirname "$record_file")"
  jq -c '.reopened = [5]' <<<"$EMPTY_RECORD" >"$record_file"
  run_gate
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_reopened_line 5)")" ]
}

@test "while a reopened decision waits, a step's report under a switched kind gets no go: it reaches the operator, the mark kept" {
  . "$lib/step-go.sh"
  switch_kinds step-go
  step_report
  mkdir -p "$(dirname "$record_file")"
  jq -c '.reopened = [3]' <<<"$EMPTY_RECORD" >"$record_file"
  run_gate false "$step_reply"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(gate_step_operator_note "$step_question" "$(gate_reopened_step_line 3)")" ]
  [ "$(jq -c '.reopened' "$record_file")" = '[3]' ]
  [ "$(last_line | jq -r '.outcome')" = to-operator ]
}

@test "\"leave it for later?\" reaches the operator, even once through the trial: work put off is theirs" {
  switch_kinds step-timing
  kind step-timing accept
  answer_for reader "$(asking "Leave the cleanup for later?" "later" "now")"
  answer_for sorter "$(sorted step-timing defers)"
  run_gate
  answered_operator
  [ "$(message)" = "$(operator_message_for "Leave the cleanup for later?" "$(gate_defers_line later)")" ]
  [ "$(jq -c '{outcome, approved}' "$(log_file)")" = '{"outcome":"to-operator","approved":""}' ]
}

@test "a settling that cannot be logged is never given: the question goes to the operator, saying why" {
  switch_kinds step-timing
  kind step-timing accept
  answer_for reader "$(asking "Which step first?" "step 3" "step 4")"
  answer_for sorter "$(sorted step-timing)"
  mkdir -p "$history/log"
  chmod a-w "$history/log"
  run_gate
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  why="$(gate_settle_unlogged_line "step 3")"$'\n'"$(gate_log_failed_line "$(refuse_log_unwritable_note "$history/log")")"
  [ "$(message)" = "$(gate_operator_note "Which step first?" "$why")" ]
}

@test "a function's name held after \"are you sure?\" is asked nothing more: on trial it reaches the operator as held twice" {
  kind inner-naming light
  answer_for sorter "$(sorted inner-naming)"
  run_gate
  [ "$(reason)" = "$(gate_challenge_note "$are_you_sure")" ]
  [ "$(jq -r '.ladder.route' "$record_file")" = light ]
  answer_for matcher "$(item five)"
  rm "$FAKE_CALLS"
  run_gate true "Yes, five."
  answered_operator
  [ "$(calls)" = "matcher $MATCHER_MODEL"$'\n'"summary $SUMMARY_MODEL" ]
  [ "$(message)" = "$(printf '%s\n%s' "$(gate_held_note "$asked" five 2 "$(gate_trial_line inner-naming)")" "$(story)")" ]
  [ "$(jq -c '{kind, outcome, approved, ladder}' "$(log_file)")" = \
    "$(jq -cn --argjson pick "$(item five)" '{kind: "inner-naming", outcome: "would-have-approved", approved: "five",
      ladder: {first: {options: ["five", "ten"], recommended: "five"}, picks: [$pick]}}')" ]
}

@test "once through the trial, a function's name held after \"are you sure?\" stands, logged as settled" {
  switch_kinds inner-naming
  kind inner-naming light
  answer_for sorter "$(sorted inner-naming)"
  run_gate
  [ "$(reason)" = "$(gate_challenge_note "$are_you_sure")" ]
  answer_for matcher "$(item five)"
  rm "$FAKE_CALLS"
  run_gate true "Yes, five."
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(gate_settled_note five)" ]
  [ "$(calls)" = "matcher $MATCHER_MODEL" ]
  [ "$(jq -c '{kind, outcome, approved}' "$(log_file)")" = '{"kind":"inner-naming","outcome":"settled","approved":"five"}' ]
  [ "$(jq -c '[.exchange[] | .from]' "$(log_file)")" = '["agent","stand-in","agent"]' ]
}

@test "a function's name that moves after \"are you sure?\" reaches the operator, with no bigger look and no cold reading" {
  switch_kinds inner-naming
  kind inner-naming light
  answer_for sorter "$(sorted inner-naming)"
  answer_for reading '{"reading":"Either."}'
  run_gate
  answer_for matcher "$(item ten)"
  rm "$FAKE_CALLS"
  run_gate true "On reflection, ten."
  answered_operator
  [ "$(message)" = "$(operator_message "$(gate_moved_line)")" ]
  [ "$(calls)" = "matcher $MATCHER_MODEL"$'\n'"summary $SUMMARY_MODEL" ]
  [ "$(grep -cxF -- "$(gate_challenge_note "$bigger_look")" "$FAKE_PROMPT.summary")" -eq 0 ]
  [ "$(jq -c '{outcome, approved}' "$(log_file)")" = '{"outcome":"to-operator","approved":""}' ]
}

@test "a module's name always reaches the operator, even once through the trial: challenged first, then theirs" {
  switch_kinds new-module
  kind new-module ask "Do we really need a new module?"
  answer_for reader "$(asking "Call the new module mf-pager or mf-pages?" mf-pager mf-pages)"
  answer_for sorter "$(sorted new-module)"
  run_gate
  [ "$(reason)" = "$(gate_challenge_note "Do we really need a new module?")" ]
  answer_for reader "$(no_question_form keep-all)"
  run_gate true
  answered_operator
  [ "$(message)" = "$(operator_message_for "Call the new module mf-pager or mf-pages?" \
    "$(gate_kind_line new-module "The new-module kind.")"$'\n'"$(gate_kept_line)")" ]
  [ "$(calls | grep -c '^matcher ')" -eq 0 ]
}

# --- The closing loop.

# The suite's session holding its brief, file-trash, working in aidk-plans;
# another session holding frozen-account, working in monoframe/mf-users; and
# the project under git, every file committed.
closing_ground() {
  . "$lib/closing.sh"
  hold_brief
  printf -- '---\nsummary: Frozen.\nafter: []\ntouches: [monoframe/mf-users]\ncreates: []\n---\n\n# frozen-account\n' \
    >"$project/aidk-plans/frozen-account.md"
  printf 'session: session-2\nsince: 2026-10-06T09:00:00Z\n' >"$project/aidk-organizer/taken/frozen-account"
  mkdir -p "$project/monoframe/mf-users/src" "$project/monoframe/mf-media/src"
  printf 'users\n' >"$project/monoframe/mf-users/src/users.ts"
  printf 'media\n' >"$project/monoframe/mf-media/src/media.ts"
  printf 'sizes\n' >"$project/monoframe/mf-media/src/sizes.ts"
  git -C "$project" init -q
  git -C "$project" add -A
  git -C "$project" -c user.name=suite -c user.email=suite@example.invalid commit -qm ground
}

# A reader's form of a reply saying the work is done.
done_form() { jq -c '.claims_done = true' <<<"$(no_question_form)"; }
done_reply="The brief is done: every step is built and its proof passed."

# One finding as the closing reader writes it: what it is, its sort, its
# files as a JSON array, and the brief it is handed to.
finding() {
  jq -cn --arg f "$1" --arg sort "$2" --argjson files "${3:-[]}" --arg brief "${4:-}" \
    '{finding: $f, sort: $sort, files: $files, brief: $brief}'
}

# The closing reader's form of a look's reply holding the findings given,
# saying nothing is left exactly where none of them belongs here.
look_form() {
  local findings
  findings="$(printf '%s\n' "$@" | jq -cs 'map(select(. != null))')"
  jq -cn --argjson findings "$findings" '{findings: $findings, nothing_left: all($findings[]; .sort != "here")}'
}

# A sweep started by a reply saying the work is done, on a new turn.
start_sweep() {
  answer_for reader "$(done_form)"
  run_gate false "$done_reply"
}

# The reply to a look, read by the closing reader as the form given.
look_reply() {
  answer_for closing "$1"
  run_gate true "${2:-I looked around.}"
}

# A whole round: the sweep started, then each look answered as given.
sweep_round() {
  start_sweep
  look_reply "$1"
  look_reply "$2"
}

# A look as the gate sends it, with how to report.
look_note() { gate_challenge_note "$1"; to_closing_report_note; }

# The log's last line.
last_line() { tail -n 1 "$(log_file)"; }

here_finding="$(finding "The README still calls the loop beta" here '["aidk-plans/stand-in-loops.md"]')"

@test "a reply saying the work is done is sent the cleanup look, read by the reader alone" {
  closing_ground
  start_sweep
  [ "$status" -eq 0 ]
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(look_note "$cleanup_look")" ]
  [[ "$(reason)" == "From the stand-in: "* ]]
  [ "$(calls)" = "reader $READER_MODEL" ]
  [ "$(jq -c '{round, closing}' "$record_file")" = '{"round":"cleanup-look","closing":{"briefs":["file-trash"],"findings":[]}}' ]
}

@test "each look's reply is read by the closing reader alone, handed the briefs other sessions hold" {
  closing_ground
  start_sweep
  rm "$FAKE_CALLS"
  look_reply "$(look_form)" "Nothing to tidy."
  [ "$(reason)" = "$(look_note "$use_look")" ]
  [ "$(calls)" = "closing $CLOSING_MODEL" ]
  prompt="$FAKE_PROMPT.closing"
  grep -qxF -- "- frozen-account" "$prompt"
  [ "$(grep -c -- "- file-trash" "$prompt")" -eq 0 ]
  grep -qF -- "$project" "$prompt"
  grep -qxF -- "Nothing to tidy." "$prompt"
  grep -qF -- '"enum":["","frozen-account"]' "$FAKE_ARGS.closing"
  [ "$(jq -r '.round' "$record_file")" = use-look ]
}

@test "a finding of each sort from both looks: what belongs here is asked, a copy switched over in passing, another session's area handed off, the rest parked or dropped" {
  closing_ground
  sweep_round \
    "$(look_form "$here_finding" \
      "$(finding "A typo the notes already hold" written-down)" \
      "$(finding "A settings screen of its own" park)")" \
    "$(look_form \
      "$(finding "media.ts builds the sizes by hand; switch it to the new reader" quick '["monoframe/mf-media/src/media.ts"]')" \
      "$(finding "mf-users could take it in its own screens" hand-off '[]' frozen-account)" \
      "$(finding "It could also be used for logging" not-same-job)")"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  expected="$(closing_here_note
    gate_problem_line "The README still calls the loop beta"
    closing_quick_heading
    gate_problem_line "media.ts builds the sizes by hand; switch it to the new reader"
    closing_hand_off_heading
    closing_hand_off_line "mf-users could take it in its own screens" frozen-account ""
    closing_park_heading
    gate_problem_line "A settings screen of its own")"
  [ "$(reason)" = "$expected" ]
  # One line for the round, every finding with its look and its sort.
  line="$(last_line)"
  [ "$(jq -c '{number, question, outcome, kind, approved, answer, briefs}' <<<"$line")" = \
    "$(jq -cn --arg q "$(closing_round_question 1)" '{number: 1, question: $q, outcome: "to-agent", kind: null, approved: "", answer: "", briefs: ["file-trash"]}')" ]
  [ "$(jq -c '.closing | {number, briefs}' <<<"$line")" = '{"number":1,"briefs":["file-trash"]}' ]
  [ "$(jq -c '[.closing.findings[] | [.look, .sort, .moved]]' <<<"$line")" = \
    '[["cleanup-look","here",""],["cleanup-look","written-down",""],["cleanup-look","park",""],["use-look","quick",""],["use-look","hand-off",""],["use-look","not-same-job",""]]' ]
  [ "$(jq -c '.closing.findings[4].briefs' <<<"$line")" = '["frozen-account"]' ]
  [ "$(jq -c '[.exchange[] | .from]' <<<"$line")" = '["agent","stand-in","agent","stand-in","agent"]' ]
  [ "$(jq -c . "$record_file")" = "$EMPTY_RECORD" ]
  # A round is no question of the operator's: nothing they type is its answer.
  run "$BATS_TEST_DIRNAME/../hooks/answer-hook.sh" <<<"$(jq -cn --arg s "$session" '{session_id: $s, hook_event_name: "UserPromptSubmit", prompt: "fine"}')"
  [ "$(last_line | jq -r '.answer')" = "" ]
}

@test "a quick finding in a file another session's brief works in is handed off into that brief, never fixed in passing" {
  closing_ground
  sweep_round "$(look_form "$here_finding")" \
    "$(look_form "$(finding "users.ts copies the new reader by hand" quick '["monoframe/mf-users/src/users.ts"]')")"
  expected="$(closing_here_note
    gate_problem_line "The README still calls the loop beta"
    closing_hand_off_heading
    closing_hand_off_line "users.ts copies the new reader by hand" frozen-account "$(closing_moved_held_words)")"
  [ "$(reason)" = "$expected" ]
  [ "$(last_line | jq -c '.closing.findings[1] | {sort, briefs, moved}')" = '{"sort":"hand-off","briefs":["frozen-account"],"moved":"held"}' ]
}

@test "a quick finding whose files hold changes nobody committed is parked, never fixed in passing" {
  closing_ground
  printf 'edited\n' >>"$project/monoframe/mf-media/src/sizes.ts"
  printf 'new\n' >"$project/monoframe/mf-media/src/fresh.ts"
  sweep_round "$(look_form "$here_finding")" \
    "$(look_form "$(finding "sizes.ts repeats the table" quick '["monoframe/mf-media/src/sizes.ts"]')" \
      "$(finding "fresh.ts repeats it too" quick '["monoframe/mf-media/src/fresh.ts"]')" \
      "$(finding "media.ts repeats it as well" quick '["monoframe/mf-media/src/media.ts"]')")"
  expected="$(closing_here_note
    gate_problem_line "The README still calls the loop beta"
    closing_quick_heading
    gate_problem_line "media.ts repeats it as well"
    closing_park_heading
    closing_moved_line "sizes.ts repeats the table" "$(closing_moved_uncommitted_words)"
    closing_moved_line "fresh.ts repeats it too" "$(closing_moved_uncommitted_words)")"
  [ "$(reason)" = "$expected" ]
  [ "$(last_line | jq -c '[.closing.findings[] | [.sort, .moved]]')" = \
    '[["here",""],["park","uncommitted"],["park","uncommitted"],["quick",""]]' ]
}

@test "where git cannot tell whether a file holds uncommitted changes, nothing is fixed in passing: the operator is told why" {
  closing_ground
  rm -rf "$project/.git"
  start_sweep
  look_reply "$(look_form "$(finding "media.ts repeats the table" quick '["monoframe/mf-media/src/media.ts"]')" \
    "$here_finding")"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_changes_unknown_note monoframe/mf-media/src/media.ts)")" ]
}

# A brief waiting on the suite's brief, and one waiting on nothing, so
# finishing the suite's brief frees one and leaves the other as it was.
waiter_ground() {
  printf -- '---\nsummary: Waiter.\nafter: [file-trash]\ntouches: [aidk-plans]\ncreates: []\n---\n\n# waiter\n' \
    >"$project/aidk-plans/waiter.md"
  printf -- '---\nsummary: Alone.\nafter: []\ntouches: [aidk-plans]\ncreates: []\n---\n\n# alone\n' \
    >"$project/aidk-plans/alone.md"
  git -C "$project" add -A
  git -C "$project" -c user.name=suite -c user.email=suite@example.invalid commit -qm waiters
}

# What the organizer's own script prints finishing the suite's brief, read in
# a copy of the project as it stands and spelled for the project itself.
organizer_done() {
  local twin="$BATS_TEST_TMPDIR/twin"
  rm -rf "$twin"
  cp -r "$project" "$twin"
  CLAUDE_PROJECT_DIR="$twin" "$BATS_TEST_DIRNAME/../../organizer/bin/organizer.sh" done file-trash \
    | sed "s|^$twin/|$project/|"
}

@test "an empty round ends the loop: the stand-in finishes the brief with done, and the agent is told to commit what it printed" {
  closing_ground
  waiter_ground
  printed="$(organizer_done)"
  sweep_round "$(look_form)" "$(look_form)"
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(closing_swept_note; closing_commit_line "$cases_command"; printf '%s\n' "$printed")" ]
  [ "$printed" = "$project/aidk-plans/file-trash.md"$'\n'"$project/aidk-plans/waiter.md" ]
  [ ! -e "$project/aidk-plans/file-trash.md" ]
  grep -qxF -- "after: []" "$project/aidk-plans/waiter.md"
  [ -z "$(git -C "$project" status --porcelain -- aidk-plans/alone.md)" ]
  [ ! -e "$project/aidk-organizer/taken/file-trash" ]
  [ "$(last_line | jq -c '{outcome, closing: (.closing | {number, findings})}')" = \
    '{"outcome":"to-agent","closing":{"number":1,"findings":[]}}' ]
  [ "$(jq -c '{round, finished: .closing.finished}' "$record_file")" = \
    "$(jq -cn --arg f "$printed"$'\n' '{round: "brief-finished", finished: $f}')" ]
  # A round is no decision of a round of questions laid out before building.
  answer_for reader "$(jq -c '.asks_operator = false | .question = "" | .options = [] | .recommended = "" | .closes_round = true' <<<"$(whole_form)")"
  run_gate false "Shall I start building?"
  [ "$(message)" = "$(round_heading; round_empty_line; round_hint)" ]
}

@test "a round whose findings all belong elsewhere ends the loop too, with what to do with them" {
  closing_ground
  sweep_round "$(look_form "$(finding "A settings screen of its own" park)")" \
    "$(look_form "$(finding "media.ts builds the sizes by hand" quick '["monoframe/mf-media/src/media.ts"]')")"
  expected="$(closing_swept_note
    closing_quick_heading
    gate_problem_line "media.ts builds the sizes by hand"
    closing_park_heading
    gate_problem_line "A settings screen of its own"
    closing_commit_line "$cases_command"
    printf '%s\n' "$project/aidk-plans/file-trash.md")"
  [ "$(reason)" = "$expected" ]
}

# The reader's form of the reply after the brief was finished: the brief
# said done, the full check as given.
finished_form() { jq -c --arg proof "$1" '.claims_done = true | .proof = $proof' <<<"$(no_question_form)"; }
finished_reply="Committed. The brief built the end report; the full check passed: 470 tests."

# regression: bash turned errexit off inside command substitutions, so the
# end report, made in one, carried on past a step that failed and showed the
# operator a report missing the brief's decisions as if it were whole.
@test "an end report whose step fails is no report: the operator is told the reply was not judged, and why" {
  closing_ground
  add_log_lines "$history" "$(log_line 1 "$OUTCOME_SETTLED" session-3 2026-10-06T07:00:00Z five '["file-trash"]')"
  sweep_round "$(look_form)" "$(look_form)"
  fail_command_on jq 'any($briefs[]; . == $b)'
  answer_for reader "$(finished_form passed)"
  run_gate true "$finished_reply"
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "jq: refused by the suite")" ]
}

@test "a finished brief's end report shows every part, from the log and the organizer's own output" {
  closing_ground
  waiter_ground
  # A proposal the agent dropped under its kind's challenge, through the gate.
  kind naming ask "Do we really need it?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_gate
  answer_for reader "$(no_question_form drop)"
  run_gate true
  # A decision the stand-in settled under this brief in an earlier session,
  # and one under another brief, which is not this report's.
  add_log_lines "$history" \
    "$(log_line 2 "$OUTCOME_SETTLED" session-3 2026-10-06T07:00:00Z five '["file-trash"]')" \
    "$(log_line 3 "$OUTCOME_SETTLED" session-3 2026-10-06T07:30:00Z ten '["other-brief"]')"
  # A round finding something here, beside every other sort, one moved by code.
  printf 'edited\n' >>"$project/monoframe/mf-media/src/sizes.ts"
  sweep_round \
    "$(look_form "$here_finding" \
      "$(finding "A typo the notes already hold" written-down)" \
      "$(finding "A settings screen of its own" park)")" \
    "$(look_form \
      "$(finding "media.ts builds the sizes by hand" quick '["monoframe/mf-media/src/media.ts"]')" \
      "$(finding "sizes.ts repeats the table" quick '["monoframe/mf-media/src/sizes.ts"]')" \
      "$(finding "mf-users could take it" hand-off '[]' frozen-account)" \
      "$(finding "It could also be used for logging" not-same-job)")"
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  # Then an empty round: the brief is finished, and the agent's reply after
  # committing brings the report.
  printed="$(organizer_done)"
  sweep_round "$(look_form)" "$(look_form)"
  answer_for reader "$(finished_form passed)"
  rm "$FAKE_CALLS"
  run_gate true "$finished_reply"
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(calls)" = "reader $READER_MODEL" ]
  expected="$(end_report_heading file-trash
    end_built_line
    end_check_passed_line
    end_silent_heading
    end_silent_line 2 "Should a call be tried five or ten times? (2)" five
    gate_fixed_heading
    gate_problem_line "media.ts builds the sizes by hand"
    end_dropped_heading
    closing_finding_line "A typo the notes already hold" "$(closing_sort_words written-down)"
    closing_finding_line "It could also be used for logging" "$(closing_sort_words not-same-job)"
    end_dropped_line 1 "Five retries or ten?"
    end_parked_heading
    gate_problem_line "A settings screen of its own"
    closing_moved_line "sizes.ts repeats the table" "$(closing_moved_uncommitted_words)"
    end_cases_never_line
    end_freed_heading
    printf '%s\n' "$printed")"
  # The organizer's list closes it as its own script prints it, read in a
  # copy of the project before the gate finished the brief.
  [ "$(message)" = "$expected" ]
  [ "$(jq -c . "$record_file")" = "$EMPTY_RECORD" ]
  # The dropped proposal the report lists reopens by its number.
  answer="$(run_skill "$BATS_TEST_DIRNAME/../.." devkit-stand-in-reopen 1)"
  [ "$(jq -r '.systemMessage' <<<"$answer" | head -n 1)" = "$(reopen_dropped_heading 1 when where | head -n 1)" ]
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$answer")" = \
    "$(reopen_dropped_agent_note 1 "Five retries or ten?" "five${LADDER_OPTION_SEPARATOR}ten" five)" ]
}

@test "the end report says plainly where the check failed, was not said, or the reply could not be read, and every empty part" {
  closing_ground
  for proof in failed "" broken; do
    git -C "$project" checkout -q -- aidk-plans
    hold_brief
    rm -f "$(log_file)"
    sweep_round "$(look_form)" "$(look_form)"
    if [ "$proof" = broken ]; then
      status_for reader 3
    else
      answer_for reader "$(finished_form "$proof")"
    fi
    run_gate true "$finished_reply"
    rm -f "$FAKE_ANSWERS/reader.status"
    case "$proof" in
      failed) check="$(end_check_failed_line)" ;;
      "") check="$(end_check_unsaid_line)" ;;
      broken) check="$(end_check_unread_line "$(refuse_model_exit_note "$READER_MODEL" 3)")" ;;
    esac
    expected="$(end_report_heading file-trash
      end_built_line
      printf '%s\n' "$check"
      end_silent_heading; end_none_line
      gate_fixed_heading; end_none_line
      end_dropped_heading; end_none_line
      end_parked_heading; end_none_line
      end_cases_never_line
      end_freed_heading
      printf '%s\n' "$project/aidk-plans/file-trash.md")"
    [ "$(message)" = "$expected" ]
  done
}

@test "the end report shows how many test cases the case-writer wrote, skipped and held back, never what" {
  closing_ground
  sweep_round "$(look_form)" "$(look_form)"
  # What the case-writer's command keeps on the record, run by the agent
  # between the two stops.
  jq -c '.closing.cases = {written: 3, skipped: 1, held: 2, failed: 1}' "$record_file" >"$record_file.new"
  mv "$record_file.new" "$record_file"
  answer_for reader "$(finished_form passed)"
  run_gate true "$finished_reply"
  [ "$status" -eq 0 ]
  [ "$(message | grep '^Test cases:')" = "$(end_cases_line 3 1 2 1)" ]
  [ "$(jq -c . "$record_file")" = "$EMPTY_RECORD" ]
}

@test "a done the organizer refuses lets the reply stop: the operator is told why, with the round's findings" {
  closing_ground
  start_sweep
  look_reply "$(look_form "$(finding "A settings screen of its own" park)")"
  printf 'not a header\n' >"$project/aidk-plans/broken.md"
  look_reply "$(look_form)"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  why="$(. "$BATS_TEST_DIRNAME/../../organizer/lib/words.sh"; refuse_header_unreadable_note broken)"
  expected="$(closing_finish_failed_note "$why"
    closing_round_findings_heading
    closing_finding_line "A settings screen of its own" "$(closing_sort_words park)")"
  [ "$(message)" = "$expected" ]
  [ -e "$project/aidk-plans/file-trash.md" ]
  [ "$(jq -c . "$record_file")" = "$EMPTY_RECORD" ]
}

@test "a third round still finding something that belongs here tells the operator, with the list" {
  closing_ground
  rest="$(look_form "$here_finding" "$(finding "It could also be used for logging" not-same-job)")"
  sweep_round "$rest" "$(look_form)"
  [ "$(reason)" = "$(closing_here_note; gate_problem_line "The README still calls the loop beta")" ]
  sweep_round "$rest" "$(look_form)"
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  sweep_round "$rest" "$(look_form "$(finding "mf-users could take it" hand-off '[]' frozen-account)")"
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  expected="$(closing_notice_note 3
    closing_finding_line "The README still calls the loop beta" "$(closing_sort_words here)"
    closing_finding_line "It could also be used for logging" "$(closing_sort_words not-same-job)"
    closing_finding_line "mf-users could take it" "$(closing_sort_words hand-off), $(closing_into_words frozen-account)")"
  [ "$(message)" = "$expected" ]
  [ "$(last_line | jq -c '{number, outcome, reasons, answer}')" = \
    "$(jq -cn --arg why "$(closing_notice_why_line 3)" '{number: 3, outcome: "to-operator", reasons: [$why], answer: ""}')" ]
  [ "$(jq -c . "$record_file")" = "$EMPTY_RECORD" ]
  # The operator's answer to the notice is kept on its line.
  run "$BATS_TEST_DIRNAME/../hooks/answer-hook.sh" <<<"$(jq -cn --arg s "$session" '{session_id: $s, hook_event_name: "UserPromptSubmit", prompt: "Leave the README."}')"
  [ "$(last_line | jq -r '.answer')" = "Leave the README." ]
}

# A closing round's line of the log, written by the suite: number, session,
# the briefs swept for as a JSON array, and the sort of its one finding.
closing_line() {
  jq -c --argjson number "$1" --arg session "$2" --argjson briefs "$3" --arg sort "$4" \
    '.number = $number | .session = $session | .briefs = $briefs | .question = "A round."
      | .ladder = null | .summary = null | .outcome = "to-agent"
      | .closing = {number: 1, briefs: $briefs, findings: [{look: "cleanup-look", finding: "x", files: [], sort: $sort, briefs: [], moved: ""}]}' \
    <<<"$(log_line "$1" "$OUTCOME_TO_OPERATOR" "$2" 2026-10-06T08:00:00Z)"
}

@test "rounds whose findings belong elsewhere, other briefs' rounds and other sessions' do not count toward the notice" {
  closing_ground
  # A round of this brief whose findings all belonged elsewhere ended its
  # loop and finished the brief, so only the log shows one beside rounds
  # that go on.
  add_log_lines "$history" \
    "$(closing_line 1 "$session" '["other-brief"]' here)" \
    "$(closing_line 2 session-2 '["file-trash"]' here)" \
    "$(closing_line 3 "$session" '["other-brief"]' here)" \
    "$(closing_line 4 "$session" '["file-trash"]' park)"
  here_round="$(look_form "$here_finding")"
  sweep_round "$here_round" "$(look_form)"
  [ "$(last_line | jq -r '.closing.number')" -eq 2 ]
  sweep_round "$here_round" "$(look_form)"
  # The third round of this brief, the second finding something here: still the agent's.
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(closing_here_note; gate_problem_line "The README still calls the loop beta")" ]
  sweep_round "$here_round" "$(look_form)"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [[ "$(message)" == "$(closing_notice_note 3 | head -n 1)"* ]]
  [ "$(last_line | jq -c '{outcome, closing: .closing.number}')" = '{"outcome":"to-operator","closing":4}' ]
}

@test "a round that cannot be logged goes to the operator, since its rounds could not be counted" {
  closing_ground
  start_sweep
  look_reply "$(look_form "$here_finding")"
  mkdir -p "$history/log"
  chmod a-w "$history/log"
  look_reply "$(look_form)"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  expected="$(closing_unlogged_note 1
    closing_finding_line "The README still calls the loop beta" "$(closing_sort_words here)"
    gate_log_failed_line "$(refuse_log_unwritable_note "$history/log")")"
  [ "$(message)" = "$expected" ]
}

@test "a look whose form fails, or hands off to a brief no other session holds, goes to the operator" {
  closing_ground
  start_sweep
  look_reply "$(look_form "$(finding "A thing" unsorted)")"
  [ "$(message)" = "$(gate_broken_note "$(refuse_unsorted_note "A thing")")" ]
  start_sweep
  look_reply "$(look_form "$(finding "Hand it over" hand-off '[]' file-trash)")"
  [ "$(message)" = "$(gate_broken_note "$(refuse_brief_outside_note file-trash)")" ]
}

@test "a new turn of the operator's lets go of a round under way" {
  closing_ground
  start_sweep
  answer_for reader "$(whole_form)"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  rm "$FAKE_CALLS"
  run_gate false
  answered_operator
  [ "$(calls)" = "$(all_three)"$'\n'"summary $SUMMARY_MODEL" ]
  [ "$(jq -c '.closing' "$record_file")" = null ]
}

@test "a reply saying the work is done in a session holding no brief stops as it is; where which cannot be told, the operator is told" {
  . "$lib/closing.sh"
  mkdir -p "$project/aidk-plans"
  start_sweep
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
  hold_brief
  printf 'garbage\n' >"$project/aidk-organizer/taken/file-trash"
  start_sweep
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(closing_briefs_unknown_note "$(. "$BATS_TEST_DIRNAME/../../organizer/lib/words.sh"; refuse_held_unreadable_note file-trash)")" ]
}

@test "a preset whose closing loop lacks a message goes to the operator" {
  closing_ground
  closing="$preset_dir/challenges/closing-loop.md"
  closing_file "$cleanup_look" "$use_look" "$whole_done" | sed 's/`use-look`/`renamed`/' >"$closing"
  start_sweep
  [ "$(message)" = "$(gate_broken_note "$(refuse_ladder_message_missing_note "$closing" use-look)")" ]
}

# A step's report naming no next step, as the reader reads it.
no_next_form() { step_form '.next_step = "" | .next_step_number = 0 | .next_step_from = ""'; }
no_next_reply="Step 9 is built and its proof passed."

@test "a step's report naming no next step is asked whether the whole brief is done, and a yes starts the sweep" {
  closing_ground
  . "$lib/step-go.sh"
  step_report "$(no_next_form)"
  run_gate false "$no_next_reply"
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(gate_challenge_note "$whole_done")" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
  [ ! -e "$(log_file)" ]
  answer_for reader "$(done_form)"
  run_gate true "Yes, the whole brief is done."
  [ "$(reason)" = "$(look_note "$cleanup_look")" ]
}

@test "asked once: a second report naming no next step is weighed as any step's, and reaches the operator saying so" {
  closing_ground
  . "$lib/step-go.sh"
  step_report "$(no_next_form)"
  run_gate false "$no_next_reply"
  run_gate true "$no_next_reply"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(gate_step_operator_note "$(gate_step_question "")" "$(gate_next_unsaid_line)")" ]
  # A report naming its next step is never asked.
  answer_for reader "$(step_form)"
  run_gate false "$step_reply"
  [ "$(message)" = "$(trial_message)" ]
}

@test "a step's report naming no next step, in a session holding no brief, is weighed as before" {
  . "$lib/step-go.sh"
  kind step-go go
  mkdir -p "$project/aidk-plans"
  answer_for reader "$(no_next_form)"
  answer_for step-sorter "$clean_step_sort"
  run_gate false "$no_next_reply"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  why="$(gate_next_unsaid_line)"$'\n'"$(gate_no_brief_line)"
  [ "$(message)" = "$(gate_step_operator_note "$(gate_step_question "")" "$why")" ]
}

# --- The resume look-around.

# The mark a wait of the suite's session leaves, as given.
woken() {
  . "$lib/woken.sh"
  write_woken_mark "$history" "$session" "$1"
}

woken_file() { printf '%s/woken/%s' "$history" "$session"; }

brief_over='{"outcome":"over","kind":"brief","on":"media-bucket","why":""}'

# The look around a woken session is sent, given the wait's mark.
look_around_note() {
  . "$lib/resume.sh"
  format_resume_note "$look_around" "$1"
}

@test "a session whose wait is over is sent the preset's look around, asking no model, and its report reaches the operator, who gives the go" {
  . "$lib/resume.sh"
  woken "$brief_over"
  run_gate false "The wait is over."
  [ "$status" -eq 0 ]
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(look_around_note "$brief_over")" ]
  [[ "$(reason)" == "From the stand-in: $look_around"$'\n'* ]]
  [ -z "$(calls)" ]
  [ ! -e "$(woken_file)" ]
  [ "$(jq -c '.resumed' "$record_file")" = '{"kind":"brief","on":"media-bucket"}' ]
  # The report asks nothing: it reaches the operator, and the reply stops.
  answer_for reader "$(no_question_form)"
  run_gate true "media-bucket landed the bucket; my answer on sizes no longer holds."
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(format_resumed_note '{"kind":"brief","on":"media-bucket"}')" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
  [ "$(jq -c '.resumed' "$record_file")" = null ]
  # The next reply asking nothing stops as any does.
  run_gate false "Going on."
  [ -z "$output" ]
}

@test "a report that asks again a decision the wait shook goes through the gate as any question; the go after it is still the operator's, never weighed" {
  . "$lib/resume.sh"
  . "$lib/step-go.sh"
  woken "$brief_over"
  run_gate false "The wait is over."
  # The shaken decision is asked: the gate takes it as any question.
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$standing_test")" ]
  [ "$(calls)" = "$(all_three)" ]
  [ "$(jq -c '.resumed' "$record_file")" = '{"kind":"brief","on":"media-bucket"}' ]
  # The wait the session woke from outlives a new turn: the next reply
  # asking nothing reaches the operator for the go.
  answer_for reader "$(no_question_form)"
  run_gate false "Understood."
  [ "$(jq -c '.resumed' "$record_file")" = null ]
  [ "$(message)" = "$(format_resumed_note '{"kind":"brief","on":"media-bucket"}')" ]
}

@test "a step's report from a woken session reaches the operator for the go, even once its kind is switched, and the step's sorter is never asked" {
  . "$lib/resume.sh"
  switch_kinds step-go
  step_report
  woken "$brief_over"
  run_gate false "The wait is over."
  [ -z "$(calls)" ]
  run_gate true "$step_reply"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(format_resumed_note '{"kind":"brief","on":"media-bucket"}')" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
  # Once the operator has it, the next report is weighed as any.
  run_gate false "$step_reply"
  [ "$(reason)" = "$(gate_go_note)" ]
}

@test "a wait that could not be watched reaches the operator with why, and no look around is sent" {
  . "$lib/resume.sh"
  why="$(refuse_repository_no_upstream_note monoframe/mf-users)"
  mark="$(to_woken_mark refused repository monoframe/mf-users "$why")"
  woken "$mark"
  run_gate false "The wait ended."
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(resume_refused_note "$(wait_repository_words monoframe/mf-users)" "$why")" ]
  [ ! -e "$(woken_file)" ]
  [ -z "$(calls)" ]
  [ "$(jq -c '.resumed' "$record_file" 2>/dev/null || echo null)" = null ]
}

@test "a wait that ends while a question is in flight waits for it: the question climbs on, and the look around follows" {
  . "$lib/resume.sh"
  run_gate
  [ "$(reason)" = "$(gate_challenge_note "$standing_test")" ]
  woken "$brief_over"
  answer_for matcher "$(item five)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$are_you_sure")" ]
  [ -e "$(woken_file)" ]
  answer_for matcher "$(item five)"
  run_gate true
  answered_operator
  [ -e "$(woken_file)" ]
  run_gate false "The wait is over."
  [ "$(reason)" = "$(look_around_note "$brief_over")" ]
}

@test "a preset missing the look around tells the operator, and the mark stays for the next stop" {
  woken "$brief_over"
  rm "$preset_dir/challenges/resume-look-around.md"
  run_gate false "The wait is over."
  [ "$(message)" = "$(gate_broken_note "$(refuse_unreadable_file_note "$preset_dir/challenges/resume-look-around.md")")" ]
  [ -e "$(woken_file)" ]
}

@test "a mark that cannot be read tells the operator" {
  . "$lib/woken.sh"
  mkdir -p "$history/woken"
  printf '{"outcome":"maybe"}\n' >"$(woken_file)"
  run_gate false "The wait is over."
  [ "$(message)" = "$(gate_broken_note "$(refuse_woken_unreadable_note "$(woken_file)")")" ]
}

# The suite's session's wait, of the kind and on what given, watched in a
# shell of its own in the background, as the entry runs it, in a group of its
# own the teardown stops whole; its looks a tenth of a second apart; its
# process left in watcher.
watch() {
  start_in_group bash -c '. "$1"; WAIT_LOOK_SECONDS=0.1; run_wait "$3" "$2" "$4" "$5"' _ \
    "$lib/wait.sh" "$session" "$history" "$1" "$2" >/dev/null 2>&1
}

# The watch's status once it ends, within twenty seconds; 99 where it does
# not.
watch_end() {
  local i
  for i in $(seq 200); do
    if ! kill -0 "$watcher" 2>/dev/null; then
      wait "$watcher"
      return
    fi
    sleep 0.1
  done
  return 99
}

@test "proof: a waiting session wakes when the brief it waits for is finished and gone, reports, and waits for the go" {
  . "$lib/resume.sh"
  hold_brief
  printf -- '---\nsummary: Bucket.\nafter: []\ntouches: [aidk-plans]\ncreates: []\n---\n\n# media-bucket\n' \
    >"$project/aidk-plans/media-bucket.md"
  watch brief media-bucket
  for i in $(seq 200); do grep -qxF -- "after: [media-bucket]" "$project/aidk-plans/file-trash.md" && break; sleep 0.1; done
  sleep 3
  kill -0 "$watcher"
  [ ! -e "$(woken_file)" ]
  "$BATS_TEST_DIRNAME/../../organizer/bin/organizer.sh" done media-bucket >/dev/null
  [ ! -e "$project/aidk-plans/media-bucket.md" ]
  watch_end
  run_gate false "The wait is over."
  [ "$(reason)" = "$(look_around_note "$brief_over")" ]
  answer_for reader "$(no_question_form)"
  run_gate true "media-bucket landed; nothing I decided is shaken."
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(format_resumed_note '{"kind":"brief","on":"media-bucket"}')" ]
}

@test "proof: a session waiting on a repository wakes when it holds nothing uncommitted and nothing unpushed, and not before" {
  . "$lib/resume.sh"
  remote="$BATS_TEST_TMPDIR/remote.git"
  module="$project/monoframe/mf-users"
  git init -q --bare "$remote"
  mkdir -p "$module"
  git -C "$module" init -q -b main
  printf 'users\n' >"$module/users.ts"
  git -C "$module" add -A
  git -C "$module" -c user.name=suite -c user.email=suite@example.invalid commit -qm ground
  git -C "$module" remote add origin "$remote"
  git -C "$module" push -q -u origin main
  # Uncommitted alone keeps it waiting.
  printf 'edit\n' >>"$module/users.ts"
  watch repository monoframe/mf-users
  sleep 1
  kill -0 "$watcher"
  [ ! -e "$(woken_file)" ]
  # Unpushed alone keeps it waiting.
  git -C "$module" add -A
  git -C "$module" -c user.name=suite -c user.email=suite@example.invalid commit -qm edit
  sleep 1
  kill -0 "$watcher"
  [ ! -e "$(woken_file)" ]
  # Neither: it wakes.
  git -C "$module" push -q
  watch_end
  mark='{"outcome":"over","kind":"repository","on":"monoframe/mf-users","why":""}'
  run_gate false "The wait is over."
  [ "$(reason)" = "$(look_around_note "$mark")" ]
  answer_for reader "$(no_question_form)"
  run_gate true "mf-users landed the frozen flag."
  [ "$(message)" = "$(format_resumed_note '{"kind":"repository","on":"monoframe/mf-users"}')" ]
}

# --- The exam owed.

# An edit of the preset's kind named, noted by the stand-in's edit hook as
# Claude Code hands it an Edit of that file.
edit_kind() {
  run --separate-stderr "$BATS_TEST_DIRNAME/../hooks/edit-hook.sh" <<<"$(jq -cn --arg s "$session" \
    --arg p "$preset_dir/questions/$1.md" '{session_id: $s, hook_event_name: "PostToolUse", tool_name: "Edit",
      tool_input: {file_path: $p, old_string: "a", new_string: "b"}, tool_response: {}}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# The words a report is sent back with while the session owes the exam for
# an edit of the kind named.
owed_note() {
  gate_exam_owed_note "$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/stand-in.sh exam" \
    "$(owed_file_line "$preset_dir/questions/$1.md")"
}

owed_file() { printf '%s/owed/%s' "$history" "$session"; }

@test "a step's report from a session owing the exam is sent back to run it first, before its problems are labelled" {
  . "$lib/step-go.sh"
  step_report
  edit_kind naming
  run_gate false "$step_reply"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(owed_note naming)" ]
  [[ "$(reason)" == "From the stand-in: run the exam first."* ]]
  [ "$(calls)" = "reader $READER_MODEL" ]
  [ ! -e "$(log_file)" ]
}

@test "a claim of done, and a report naming no next step, are sent back to run the exam too; a question is not held for it" {
  closing_ground
  . "$lib/step-go.sh"
  edit_kind naming
  answer_for reader "$(done_form)"
  run_gate false "$done_reply"
  [ "$(reason)" = "$(owed_note naming)" ]
  step_report "$(no_next_form)"
  run_gate false "$no_next_reply"
  [ "$(reason)" = "$(owed_note naming)" ]
  answer_for reader "$(whole_form)"
  run_gate false
  [ "$(reason)" = "$(gate_challenge_note "$standing_test")" ]
}

@test "a report sent back for the exam as often as it may be reaches the operator, the exam still owed" {
  . "$lib/step-go.sh"
  step_report
  edit_kind naming
  run_gate false "$step_reply"
  run_gate true "$step_reply"
  run_gate true "$step_reply"
  [ "$(reason)" = "$(owed_note naming)" ]
  run_gate true "$step_reply"
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(gate_exam_owed_operator_note 3 "$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/stand-in.sh exam" \
    "$(owed_file_line "$preset_dir/questions/naming.md")")" ]
  [ -f "$(owed_file)" ]
}

@test "proof: an edit made inside the closing loop holds its end: the empty round sends the exam first, and the brief is not finished" {
  closing_ground
  start_sweep
  look_reply "$(look_form)"
  # The stand-in's preset is edited while the loop runs, after the claim of
  # done that started it.
  edit_kind naming
  look_reply "$(look_form)"
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(owed_note naming)" ]
  [ -e "$project/aidk-plans/file-trash.md" ]
  [ -e "$project/aidk-organizer/taken/file-trash" ]
  [ "$(jq -c '{round, closing}' "$record_file")" = '{"round":null,"closing":null}' ]
  # Once the exam has passed, the next claim of done sweeps again.
  rm "$(owed_file)"
  answer_for reader "$(done_form)"
  run_gate true "$done_reply"
  [ "$(reason)" = "$(look_note "$cleanup_look")" ]
}

@test "proof: after an edit, a step's report is sent back until the exam passes; a passing exam clears it, and the session's end clears a new one" {
  . "$lib/step-go.sh"
  step_report
  export CLAUDE_CODE_SESSION_ID="$session"
  # A case the operator did not take the recommendation of, which passed the
  # last exam.
  mkdir -p "$history/answers" "$history/exam"
  printf -- '---\nsummary: A case.\nbrief: file-trash\nkind: naming\npicked-recommended: no\ntuning: none\n---\n\n=====REPLY START=====\nFive or ten?\n=====REPLY END=====\n' \
    >"$history/answers/naming.md"
  printf '%s\n' '{"passed":["naming.md"]}' >"$history/exam/last-passed.json"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  # The edit: the kind's route flipped, so the case would stand alone.
  kind naming accept
  edit_kind naming
  run_gate false "$step_reply"
  [ "$(reason)" = "$(owed_note naming)" ]
  answer_for reader "$(whole_form)"
  run --separate-stderr "$BATS_TEST_DIRNAME/../bin/stand-in.sh" exam
  [ "$status" -eq 1 ]
  [ "$(head -n 1 <<<"$output")" = "$(exam_dropped_line naming.md "")" ]
  [ -f "$(owed_file)" ]
  answer_for reader "$(step_form)"
  run_gate true "$step_reply"
  [ "$(reason)" = "$(owed_note naming)" ]
  # Put back, the exam passes, and the report is weighed for the go.
  kind naming ask
  edit_kind naming
  answer_for reader "$(whole_form)"
  run --separate-stderr "$BATS_TEST_DIRNAME/../bin/stand-in.sh" exam
  [ "$status" -eq 0 ]
  # Its line before the last, which is the time it took.
  [ "$(tail -n 2 <<<"$output" | head -n 1)" = "$(exam_mark_cleared_line)" ]
  [ ! -e "$(owed_file)" ]
  answer_for reader "$(step_form)"
  run_gate true "$step_reply"
  [ "$(message)" = "$(trial_message)" ]
  # A new edit, and the session ends: its exam owed goes with it.
  edit_kind naming
  [ -f "$(owed_file)" ]
  run --separate-stderr "$BATS_TEST_DIRNAME/../hooks/end-hook.sh" <<<"$(jq -cn --arg s "$session" '{session_id: $s}')"
  [ "$status" -eq 0 ]
  [ ! -e "$(owed_file)" ]
}

# --- The trial's bar, the question whether a kind may answer alone, and the
# fall-back.

# A kind's score as the exam keeps it, given how many tries agreed, how many
# did not, and whether those were turned down for a security gap.
score_of() {
  jq -cn --argjson agreed "$1" --argjson missed "$2" --argjson security "${3:-false}" '{
    tries: ($agreed + $missed), agreed: $agreed,
    misses: [range($missed) | {name: "miss-\(. + 1).md", summary: "Miss \(. + 1).", security: $security}]}'
}

# The last passing exam's results, holding the scores given as one object.
kept_scores() {
  mkdir -p "$history/exam"
  jq -cn --argjson scores "$1" '{passed: [], scores: $scores}' >"$history/exam/last-passed.json"
}

# The end report brought by the reply after the brief was finished.
end_report() {
  closing_ground
  sweep_round "$(look_form)" "$(look_form)"
  answer_for reader "$(finished_form passed)"
  run_gate true "$finished_reply"
}

@test "proof: the end report asks nothing of a kind at 18 of 20, of one with a security miss, or of an always-yours kind, and asks of one at 19 of 20 with its misses" {
  kind eighteen accept
  kind security-miss ladder
  kind whole ladder
  kept_scores "$(jq -cn --argjson e "$(score_of 18 2)" --argjson n "$(score_of 20 0)" \
    --argjson s "$(score_of 39 1 true)" --argjson w "$(score_of 19 1)" \
    '{eighteen: $e, naming: $n, "security-miss": $s, whole: $w}')"
  end_report
  [ "$status" -eq 0 ]
  expected="$(end_freed_heading
    printf '%s\n' "$project/aidk-plans/file-trash.md"
    end_switch_heading whole 20 19
    end_switch_misses_heading
    end_switch_miss_line miss-1.md "Miss 1."
    end_switch_question whole yes)"
  [ "$(message | sed -n "/^$(end_freed_heading | sed 's/[.:]/./g')\$/,\$p")" = "$expected" ]
  [ "$(last_line | jq -c '{question, outcome, answer, kind: .trust.kind, tries: .trust.score.tries}')" = \
    "$(jq -cn --arg q "$(trial_switch_question_words whole)" \
      '{question: $q, outcome: "to-operator", answer: "", kind: "whole", tries: 20}')" ]
  # The question is about the stand-in, never a decision of the round laid
  # out before building.
  answer_for reader "$(round_form)"
  run_gate false "Shall I start building?"
  [ "$(message)" = "$(round_heading; round_empty_line; round_hint)" ]
  # Nothing reached the bar but kinds that may never be asked about: no
  # question, and no line for one.
  git -C "$project" checkout -q -- aidk-plans
  rm -f "$(log_file)"
  kept_scores "$(jq -cn --argjson e "$(score_of 18 2)" --argjson n "$(score_of 20 0)" \
    --argjson s "$(score_of 39 1 true)" '{eighteen: $e, naming: $n, "security-miss": $s}')"
  hold_brief
  sweep_round "$(look_form)" "$(look_form)"
  answer_for reader "$(finished_form passed)"
  run_gate true "$finished_reply"
  [ "$(message | tail -n 1)" = "$project/aidk-plans/file-trash.md" ]
  [ "$(last_line | jq -r '.trust')" = null ]
}

@test "a kind already switched is not asked about again; one that fell back since its yes is" {
  kind whole ladder
  kept_scores "$(jq -cn --argjson w "$(score_of 20 0)" '{whole: $w}')"
  switch_kinds whole
  end_report
  [ "$(message | tail -n 1)" = "$project/aidk-plans/file-trash.md" ]
  # Two of its silent decisions reopened since the yes: back on trial, and
  # asked about again, so a new yes can start the count over.
  add_log_lines "$history" \
    "$(jq -c '.kind = "whole" | .reopened = "2026-10-07T09:00:00Z"' <<<"$(log_line 50 "$OUTCOME_SETTLED" session-3 2026-10-06T07:00:00Z)")" \
    "$(jq -c '.kind = "whole" | .reopened = "2026-10-07T09:05:00Z"' <<<"$(log_line 51 "$OUTCOME_SETTLED" session-3 2026-10-06T07:10:00Z)")"
  git -C "$project" checkout -q -- aidk-plans
  hold_brief
  sweep_round "$(look_form)" "$(look_form)"
  run_gate true "$finished_reply"
  [ "$(message | tail -n 1)" = "$(end_switch_question whole yes)" ]
}

@test "which kind is due that cannot be read is said in the end report, and nothing is asked" {
  kind whole ladder
  mkdir -p "$history/exam"
  printf 'not json\n' >"$history/exam/last-passed.json"
  end_report
  [ "$status" -eq 0 ]
  [ "$(message | tail -n 2)" = "$(end_switch_unread_line "$(refuse_exam_results_unreadable_note "$history/exam/last-passed.json")")" ]
}

@test "a switch question that cannot be logged says the answer cannot be kept" {
  kind whole ladder
  kept_scores "$(jq -cn --argjson w "$(score_of 20 0)" '{whole: $w}')"
  closing_ground
  sweep_round "$(look_form)" "$(look_form)"
  answer_for reader "$(finished_form passed)"
  chmod a-w "$history/log" "$(log_file)"
  run_gate true "$finished_reply"
  [ "$(message | tail -n 2)" = "$(end_switch_unlogged_line "$(refuse_log_unwritable_note "$history/log")")" ]
}

@test "proof: two reopens of a switched kind's silent decisions send it back to the trial, told once; a newer yes starts the count again" {
  switch_kinds step-timing
  kind step-timing accept
  question="Fold step 4 into step 3?"
  answer_for sorter "$(sorted step-timing)"
  for i in 1 2 3; do
    answer_for reader "$(asking "$question" yes no)"
    run_gate
    [ "$(reason)" = "$(gate_settled_note yes)" ]
  done
  # Reopened from a session the stand-in is off for, so no mark of the
  # session's brings the next question to the operator: only the trial can.
  own="$session"
  session=elsewhere
  answer="$(run_skill "$kit" devkit-stand-in-reopen 1)"
  [ "$(jq -r '.systemMessage' <<<"$answer" | grep -c '^Stand-in: you have now reopened')" -eq 0 ]
  session="$own"
  answer_for reader "$(asking "$question" yes no)"
  run_gate
  [ "$(reason)" = "$(gate_settled_note yes)" ]
  session=elsewhere
  answer="$(run_skill "$kit" devkit-stand-in-reopen 2)"
  [ "$(jq -j .systemMessage <<<"$answer" | tail -n 1)" = \
    "$(trial_fallback_note step-timing 2 20 "$trusted_since")" ]
  session="$own"
  [ "$(jq -c '[.[] | select(.reopened != null) | .number]' <<<"$(jq -s . "$(log_file)")")" = '[1,2]' ]
  # Back on trial: the next question comes to the operator, marked as what
  # would have been accepted.
  answer_for reader "$(asking "$question" yes no)"
  run_gate
  answered_operator
  [ "$(message)" = "$(accepted_message "$question" yes "$(gate_trial_line step-timing)")" ]
  # A third reopen tells nothing more.
  session=elsewhere
  answer="$(run_skill "$kit" devkit-stand-in-reopen 3)"
  [ "$(jq -r '.systemMessage' <<<"$answer" | grep -c '^Stand-in: you have now reopened')" -eq 0 ]
  session="$own"
  # A newer yes starts the count again: settled without them once more. Given
  # a minute ahead, so no decision reopened above falls on its second.
  write_trust_file "$history" step-timing "$(date -u -d '+1 minute' +%Y-%m-%dT%H:%M:%SZ)"
  answer_for reader "$(asking "$question" yes no)"
  run_gate false
  [ "$(reason)" = "$(gate_settled_note yes)" ]
}
