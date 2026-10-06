bats_require_minimum_version 1.5.0

# Behavior tests for the gate: silent where the stand-in is off, every route a
# question can take, the challenge and its answers, the ladder, the bigger
# look around and the cold second reading, the plain retelling before every
# question reaches the operator and the summary under it, the loop guard, and
# every way the gate itself can fail letting the reply stop with a reason.
# Claude Code is the suite's own fake, answering each model apart.

load fake-claude

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
  answer_for reader "$(whole_form)"
  answer_for checker "$(clean_check)"
  answer_for sorter '{"kind":"defaults","unsure":false,"risks":[]}'
  answer_for summary "$(jq -cn --arg summary "$summary_words" '{summary: $summary}')"
}

teardown() {
  [ ! -d "$history" ] || chmod -R u+rwx "$history"
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
  printf '{"asks_operator":false,"question":"","options":[],"recommended":"","claims_done":false,"guidance_answer":"%s"}' "${1:-}"
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
      recommended: $recommended, claims_done: false, guidance_answer: ""}'
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

# The question as the agent retells it plainly, and the summary the suite's
# summary reader writes.
plain_question="Should a failed call be tried again five times or ten?"
summary_words="The agent asked whether to retry five or ten times, and kept five."

# The plain retelling, as the gate sends it.
retelling() { gate_challenge_note "$plain_retelling"; }

# The reply to the plain retelling, read as the form given, by default the
# question retold plainly. The gate's answer is left in output.
retell() {
  answer_for reader "${1:-$(jq -c --arg q "$plain_question" '.question = $q' <<<"$(whole_form)")}"
  run_gate true
}

# The operator's message for the question retold plainly, given why it came
# to them, then the summary, then the reading part where one is given.
operator_message() {
  printf '%s\n%s' "$(gate_operator_note "$plain_question" "$1")" "$(gate_summary_note "$summary_words")"
  [ -z "${2:-}" ] || printf '\n%s' "$2"
}

# The operator's message for answers that held, given why they came.
held_message() {
  printf '%s\n%s' "$(gate_held_note "$plain_question" five 3 "$1")" "$(gate_summary_note "$summary_words")"
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
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"guidance_answer":""}'
  run_gate
  [ "$status" -eq 0 ]
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(reason)" = "$(gate_no_recommendation_note)" ]
  # Decision 7 of the stand-in: every message to an agent opens so.
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
  prompt="$FAKE_PROMPT.checker"
  grep -qxF "=====ENTRY rule-one.md=====" "$prompt"
  grep -qxF "Rule one body." "$prompt"
  grep -qxF "=====ENTRY convention-one.md=====" "$prompt"
  grep -qxF "Convention one body." "$prompt"
  # Counted rather than negated: a negated command does not fail a test.
  [ "$(grep -cF "=====ENTRY README.md=====" "$prompt")" -eq 0 ]
  grep -qF -- "$reply" "$prompt"
  grep -qF -- '"enum":["convention-one.md","rule-one.md"]' "$FAKE_ARGS.checker"
}

@test "a kind with a challenge is challenged first, and a drop lets the reply stop, noted" {
  kind naming ask "Do we really need it?" "Have you read them?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  run_gate
  [ "$status" -eq 0 ]
  [ "$(reason)" = "$(gate_challenge_note "Do we really need it?")" ]
  answer_for reader "$(no_question_form drop)"
  rm "$FAKE_CALLS"
  run_gate true
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
  [ "$(jq -c '.dropped' "$record_file")" = '[{"question":"Five retries or ten?","kind":"naming"}]' ]
  [ "$(jq -c '.challenge' "$record_file")" = null ]
}

@test "a proposal kept is challenged a second time, and kept again goes to the operator" {
  kind naming ask "Do we really need it?" "Have you read them?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  run_gate
  answer_for reader "$(no_question_form keep-part)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "Have you read them?")" ]
  answer_for reader "$(no_question_form keep-all)"
  run_gate true
  [ "$(reason)" = "$(retelling)" ]
  retell
  [ "$status" -eq 0 ]
  why="$(gate_kind_line naming "The naming kind.")"$'\n'"$(gate_kept_line)"
  [ "$(message)" = "$(operator_message "$why")" ]
  [ "$(jq -c '.challenge' "$record_file")" = null ]
}

@test "a proposal kept under a one-step challenge goes on to the routes" {
  kind naming ask "Do we really need it?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  run_gate
  answer_for reader "$(no_question_form keep-all)"
  run_gate true
  [ "$(reason)" = "$(retelling)" ]
  retell
  why="$(gate_kind_line naming "The naming kind.")"$'\n'"$(gate_kept_line)"
  [ "$(message)" = "$(operator_message "$why")" ]
}

@test "a reply that answers the challenge neither way goes to the operator" {
  kind naming ask "Do we really need it?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  run_gate
  answer_for reader "$(no_question_form)"
  run_gate true
  [ "$(reason)" = "$(retelling)" ]
  retell
  [ "$(message)" = "$(operator_message "$(gate_unanswered_line "Do we really need it?")")" ]
}

@test "an always-yours kind goes to the operator, saying why, its plain retelling first and the summary under it" {
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  run_gate
  [ "$status" -eq 0 ]
  [ "$(reason)" = "$(retelling)" ]
  [[ "$(reason)" == "From the stand-in: "* ]]
  # The question as first asked is kept for the record, and the retelling is
  # no send-back.
  [ "$(jq -r '.operator.question' "$record_file")" = "Five retries or ten?" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 0 ]
  [ "$(jq -c '[.exchange[] | .text]' "$record_file")" = "$(jq -cn --arg a "$reply" --arg b "$(retelling)" '[$a, $b]')" ]
  rm "$FAKE_CALLS"
  retell
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(operator_message "$(gate_kind_line naming "The naming kind.")")" ]
  [ "$(calls)" = "reader $READER_MODEL"$'\n'"summary $SUMMARY_MODEL" ]
  grep -qxF -- "$reply" "$FAKE_PROMPT.summary"
  grep -qxF -- "$(retelling)" "$FAKE_PROMPT.summary"
  [ "$(jq -c '.' "$record_file")" = "$EMPTY_RECORD" ]
}

@test "a risk named on the recommended option goes to the operator, with the risk's words" {
  answer_for sorter '{"kind":"defaults","unsure":false,"risks":["workaround"]}'
  run_gate
  [ "$(reason)" = "$(retelling)" ]
  retell
  [ "$(message)" = "$(operator_message "$(gate_risk_line five workaround "The workaround risk.")")" ]
}

@test "a sort the sorter is unsure of goes to the operator" {
  answer_for sorter '{"kind":"defaults","unsure":true,"risks":[]}'
  run_gate
  [ "$(reason)" = "$(retelling)" ]
  retell
  [ "$(message)" = "$(operator_message "$(gate_unsure_line defaults)")" ]
}

@test "a summary that fails never holds the question: the operator is told why and shown the answers" {
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  status_for summary 124
  run_gate
  retell
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  expected="$(gate_operator_note "$plain_question" "$(gate_kind_line naming "The naming kind.")")"$'\n'
  expected+="$(gate_summary_failed_note "$(refuse_model_timeout_note "$SUMMARY_MODEL" "$SUMMARY_SECONDS")")"$'\n'
  expected+="$(gate_answers_heading; gate_answer_line 1 five "five${LADDER_OPTION_SEPARATOR}ten")"
  [ "$(message)" = "$expected" ]
}

@test "a plain retelling that asks nothing, or cannot be read, leaves the question as first asked, saying so" {
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  run_gate
  retell "$(no_question_form)"
  why="$(gate_kind_line naming "The naming kind.")"$'\n'"$(gate_retelling_unread_line "")"
  expected="$(gate_operator_note "Five retries or ten?" "$why")"$'\n'"$(gate_summary_note "$summary_words")"
  [ "$(message)" = "$expected" ]
  answer_for reader "$(whole_form)"
  run_gate
  [ "$(reason)" = "$(retelling)" ]
  status_for reader 124
  run_gate true
  why="$(gate_kind_line naming "The naming kind.")"$'\n'"$(gate_retelling_unread_line "$(refuse_model_timeout_note "$READER_MODEL" "$READER_SECONDS")")"
  [ "$(message)" = "$(gate_operator_note "Five retries or ten?" "$why")"$'\n'"$(gate_summary_note "$summary_words")" ]
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
  [ "$status" -eq 0 ]
  [ "$(reason)" = "$(retelling)" ]
  retell
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(held_message "$(gate_trial_line defaults)")" ]
  [[ "$(message)" == "Stand-in: a question for you: $plain_question"$'\n'* ]]
  [ "$(calls)" = "matcher $MATCHER_MODEL"$'\n'"matcher $MATCHER_MODEL"$'\n'"reader $READER_MODEL"$'\n'"summary $SUMMARY_MODEL" ]
  [ "$(jq -c '.ladder' "$record_file")" = null ]
}

@test "an answer that moves is sent the bigger look around once, then reaches the operator with the reading" {
  answer_for reading '{"reading":"Ten is safer."}'
  climb "$(item ten)"
  rm "$FAKE_CALLS"
  answer_for matcher "$(item five)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$bigger_look")" ]
  [ "$(calls)" = "matcher $MATCHER_MODEL" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 2 ]
  rm "$FAKE_CALLS"
  answer_for matcher "$(item ten)"
  run_gate true "I looked further: ten."
  [ "$(reason)" = "$(retelling)" ]
  [ "$(calls)" = "matcher $MATCHER_MODEL"$'\n'"reading $READING_MODEL" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 2 ]
  [ "$(jq -c '.ladder.picks' "$record_file")" = "[$(item ten),$(item five),$(item ten)]" ]
  retell
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(operator_message "$(gate_moved_line)" "$(gate_reading_note "Ten is safer.")")" ]
  # Each fixed round went to the agent once, and the summary was handed the
  # whole exchange.
  [ "$(grep -cxF -- "$(gate_challenge_note "$bigger_look")" "$FAKE_PROMPT.summary")" -eq 1 ]
  [ "$(grep -cxF -- "$(retelling)" "$FAKE_PROMPT.summary")" -eq 1 ]
  grep -qxF -- "$(gate_challenge_note "$standing_test")" "$FAKE_PROMPT.summary"
  grep -qxF -- "I looked further: ten." "$FAKE_PROMPT.summary"
  [ "$(jq -c '.ladder' "$record_file")" = null ]
}

@test "the cold reading is the advisor's command, handed the question and options alone, reading the project" {
  answer_for reading '{"reading":"Ten is safer."}'
  climb "$(item ten)" "$(item five)" "$(item five)"
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
  climb "$(item ten)" "$(item five)" "$(item five)"
  [ "$(reason)" = "$(retelling)" ]
  retell
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(operator_message "$(gate_moved_line)" \
    "$(gate_reading_failed_line "$(refuse_model_timeout_note "$READING_MODEL" "$READING_SECONDS")")")" ]
  rm "$FAKE_ANSWERS/reading.status"
  answer_for reading '{"reading":"  "}'
  climb "$(item ten)" "$(item five)" "$(item five)"
  retell
  [[ "$(message)" == *"$(gate_reading_failed_line "$(refuse_reading_empty_note)")" ]]
}

@test "a summary that fails after a ladder shows every answer, the bigger look's marked" {
  answer_for reading '{"reading":"Either."}'
  status_for summary 3
  climb "$(item ten)" "$(new_pick)" "$(gone_pick)"
  retell
  list="five${LADDER_OPTION_SEPARATOR}ten"
  expected="$(gate_operator_note "$plain_question" "$(gate_moved_line)")"$'\n'
  expected+="$(gate_summary_failed_note "$(refuse_model_exit_note "$SUMMARY_MODEL" 3)")"$'\n'
  expected+="$(gate_answers_heading
    gate_answer_line 1 five "$list"
    gate_pick_line 2 ten
    gate_pick_new_line 3
    gate_answer_gone_line "$(gate_looked_number 4)")"$'\n'
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
  retell
  [ "$(message)" = "$(held_message "$(gate_trial_line defaults)"$'\n'"$(gate_kept_line)")" ]
}

@test "a preset whose ladder lacks any named message goes to the operator, whichever is needed now" {
  ladder_file="$preset_dir/challenges/challenge-ladder.md"
  for name in standing-test are-you-sure bigger-look plain-retelling; do
    ladder_file "$standing_test" "$are_you_sure" "$bigger_look" "$plain_retelling" \
      | sed "s/\`$name\`/\`renamed\`/" >"$ladder_file"
    run_gate
    [ "$status" -eq 0 ]
    [ "$(message)" = "$(gate_broken_note "$(refuse_ladder_message_missing_note "$ladder_file" "$name")")" ]
  done
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  run_gate
  [ "$(message)" = "$(gate_broken_note "$(refuse_ladder_message_missing_note "$ladder_file" plain-retelling)")" ]
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

@test "the ladder's challenges count toward the send-back limit, and the loop guard still sends the retelling" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"guidance_answer":""}'
  run_gate false
  run_gate true
  answer_for reader "$(rung_form five)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "$standing_test")" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  answer_for matcher "$(item five)"
  run_gate true
  [ "$(reason)" = "$(retelling)" ]
  retell
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(operator_message "$(gate_loop_line 3 "$(gate_challenge_note "$are_you_sure")")")" ]
  [ "$(jq -c '.ladder' "$record_file")" = null ]
}

@test "the fixed rounds are never counted: a ladder at the limit is still sent the bigger look and the retelling" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"guidance_answer":""}'
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
  [ "$(reason)" = "$(retelling)" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  retell
  [ "$(message)" = "$(operator_message "$(gate_moved_line)" "$(gate_reading_note "Ten is safer.")")" ]
}

@test "a fixed round already sent for the question is never sent again" {
  answer_for reading '{"reading":"Ten is safer."}'
  climb "$(item ten)"
  jq -c '.rounds_sent = ["bigger-look"]' "$record_file" >"$record_file.new" && mv "$record_file.new" "$record_file"
  answer_for matcher "$(item five)"
  run_gate true
  [ "$(reason)" = "$(retelling)" ]
  [ "$(calls | tail -n 2)" = "matcher $MATCHER_MODEL"$'\n'"reading $READING_MODEL" ]
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  jq -c '.round = null | .operator = null | .ladder = null' "$record_file" >"$record_file.new" && mv "$record_file.new" "$record_file"
  answer_for reader "$(whole_form)"
  run_gate true
  [ "$(message)" = "$(gate_broken_note "$(refuse_round_twice_note plain-retelling)")" ]
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
  answer_for reader '{"asks_operator":true,"question":"Five or ten?","options":["five","ten"],"recommended":"seven","claims_done":false,"guidance_answer":""}'
  run_gate
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_recommended_outside_note seven)")" ]
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
  [ "$(message)" = "$(gate_broken_note "$(refuse_kind_route_note defaults maybe ask ladder)")" ]
}

@test "a question sent back three times in a row goes to the operator on the fourth" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"guidance_answer":""}'
  run_gate false
  run_gate true
  run_gate true
  [ "$(reason)" = "$(gate_no_recommendation_note)" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  run_gate true
  [ "$(reason)" = "$(retelling)" ]
  retell
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(operator_message "$(gate_loop_line 3 "$(gate_no_recommendation_note)")")" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 0 ]
}

@test "the loop guard reached through the checker, with the retelling missing from the preset, goes to the operator as a broken gate" {
  answer_for checker '{"breaks":[],"miscalled":[],"explains_code":true}'
  ladder_file="$preset_dir/challenges/challenge-ladder.md"
  ladder_file "$standing_test" "$are_you_sure" "$bigger_look" "$plain_retelling" \
    | sed 's/`plain-retelling`/`renamed`/' >"$ladder_file"
  run_gate false
  run_gate true
  run_gate true
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  run_gate true
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_ladder_message_missing_note "$ladder_file" plain-retelling)")" ]
}

@test "a new turn of the operator's starts the count again" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"guidance_answer":""}'
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
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"guidance_answer":""}'
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

@test "the jobs together fit inside the time limit the gate is registered with" {
  [ "$(derive_jobs_seconds)" -lt "$GATE_HOOK_SECONDS" ]
}
