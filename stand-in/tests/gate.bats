bats_require_minimum_version 1.5.0

# Behavior tests for the gate: silent where the stand-in is off, every route a
# question can take, the challenge and its answers, the ladder and its cold
# second reading, the loop guard, and every way the gate itself can fail
# letting the reply stop with a reason. Claude Code is the suite's own fake,
# answering each model apart.

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

# The ladder climbed from the suite's question: the first stop puts it on the
# ladder, and each form given is read from the reply to the next rung, in
# order. The gate's answer to the last stop is left in output.
climb() {
  run_gate
  local form
  for form in "$@"; do
    answer_for reader "$form"
    run_gate true
  done
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
  ! grep -qF "=====ENTRY README.md=====" "$prompt"
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
  [ "$status" -eq 0 ]
  why="$(gate_kind_line naming "The naming kind.")"$'\n'"$(gate_kept_line)"
  [ "$(message)" = "$(gate_operator_note "Five retries or ten?" "$why")" ]
  [ "$(jq -c '.challenge' "$record_file")" = null ]
}

@test "a proposal kept under a one-step challenge goes on to the routes" {
  kind naming ask "Do we really need it?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  run_gate
  answer_for reader "$(no_question_form keep-all)"
  run_gate true
  why="$(gate_kind_line naming "The naming kind.")"$'\n'"$(gate_kept_line)"
  [ "$(message)" = "$(gate_operator_note "Five retries or ten?" "$why")" ]
}

@test "a reply that answers the challenge neither way goes to the operator" {
  kind naming ask "Do we really need it?"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  run_gate
  answer_for reader "$(no_question_form)"
  run_gate true
  [ "$(message)" = "$(gate_operator_note "Five retries or ten?" "$(gate_unanswered_line "Do we really need it?")")" ]
}

@test "an always-yours kind goes to the operator, saying why" {
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[]}'
  run_gate
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(gate_operator_note "Five retries or ten?" "$(gate_kind_line naming "The naming kind.")")" ]
  [ ! -e "$record_file" ]
}

@test "a risk named on the recommended option goes to the operator, with the risk's words" {
  answer_for sorter '{"kind":"defaults","unsure":false,"risks":["workaround"]}'
  run_gate
  [ "$(message)" = "$(gate_operator_note "Five retries or ten?" "$(gate_risk_line five workaround "The workaround risk.")")" ]
}

@test "a sort the sorter is unsure of goes to the operator" {
  answer_for sorter '{"kind":"defaults","unsure":true,"risks":[]}'
  run_gate
  [ "$(message)" = "$(gate_operator_note "Five retries or ten?" "$(gate_unsure_line defaults)")" ]
}

@test "a ladder kind with no risk, sorted for certain, is sent the ladder's first challenge" {
  run_gate
  [ "$status" -eq 0 ]
  [ "$(reason)" = "$(gate_challenge_note "${ladder_challenges[0]}")" ]
  [[ "$(reason)" == "From the stand-in: ${ladder_challenges[0]}"* ]]
  [ "$(jq -c '.ladder.answers' "$record_file")" = '[{"asks_operator":true,"options":["five","ten"],"recommended":"five"}]' ]
}

@test "the same answer on every rung holds, and during the trial still comes to the operator" {
  run_gate
  answer_for reader "$(rung_form five)"
  rm "$FAKE_CALLS"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "${ladder_challenges[1]}")" ]
  [ "$(calls)" = "reader $READER_MODEL" ]
  run_gate true
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [ "$(message)" = "$(gate_held_note "Five retries or ten?" five 3 "$(gate_trial_line defaults)")" ]
  [[ "$(message)" == "Stand-in: a question for you: Five retries or ten?"$'\n'* ]]
  [ "$(calls)" = "reader $READER_MODEL"$'\n'"reader $READER_MODEL" ]
  [ "$(jq -c '.ladder' "$record_file")" = null ]
}

@test "an answer that moves comes to the operator with every answer in order and the cold reading" {
  answer_for reading '{"reading":"Ten is safer."}'
  climb "$(rung_form ten)" "$(rung_form five)"
  [ "$status" -eq 0 ]
  list="five${LADDER_OPTION_SEPARATOR}ten"
  expected="$(gate_operator_note "Five retries or ten?" "$(gate_moved_line)"$'\n'
    gate_answers_heading 3
    gate_answer_line 1 five "$list"
    gate_answer_line 2 ten "$list"
    gate_answer_line 3 five "$list"
    gate_reading_note "Ten is safer.")"
  [ "$(message)" = "$expected" ]
  [ "$(calls | tail -n 2)" = "reader $READER_MODEL"$'\n'"reading $READING_MODEL" ]
  [ "$(jq -c '.ladder' "$record_file")" = null ]
}

@test "the cold reading is the advisor's command, handed the question and options alone, reading the project" {
  answer_for reading '{"reading":"Ten is safer."}'
  climb "$(rung_form ten)" "$(rung_form five)"
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

@test "reworded options with the same recommended label count as a change" {
  answer_for reading '{"reading":"Either."}'
  climb "$(rung_form five '["five","twenty"]')" "$(rung_form five)"
  [[ "$(message)" == "$(gate_operator_note "Five retries or ten?" "$(gate_moved_line)")"* ]]
  [[ "$(message)" == *"$(gate_answer_line 2 five "five${LADDER_OPTION_SEPARATOR}twenty")"* ]]
}

@test "a rung whose reply no longer asks the question counts as a change, and the last rung is still asked" {
  answer_for reading '{"reading":"Either."}'
  run_gate
  answer_for reader "$(no_question_form)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "${ladder_challenges[1]}")" ]
  answer_for reader "$(rung_form five)"
  run_gate true
  [[ "$(message)" == "$(gate_operator_note "Five retries or ten?" "$(gate_moved_line)")"* ]]
  [[ "$(message)" == *"$(gate_answer_gone_line 2)"* ]]
}

@test "a reading that fails still brings the operator every answer, saying why there is none" {
  status_for reading 124
  climb "$(rung_form ten)" "$(rung_form five)"
  [ "$status" -eq 0 ]
  [ "$(jq -r 'has("decision")' <<<"$output")" = false ]
  [[ "$(message)" == *"$(gate_answer_line 3 five "five${LADDER_OPTION_SEPARATOR}ten")"* ]]
  [[ "$(message)" == *"$(gate_reading_failed_line "$(refuse_model_timeout_note "$READING_MODEL" "$READING_SECONDS")")" ]]
  rm "$FAKE_ANSWERS/reading.status"
  answer_for reading '{"reading":"  "}'
  climb "$(rung_form ten)" "$(rung_form five)"
  [[ "$(message)" == *"$(gate_reading_failed_line "$(refuse_reading_empty_note)")" ]]
}

@test "a question kept through its challenge goes up the ladder, the operator told it was kept" {
  kind defaults ladder "Do we really need it?"
  run_gate
  answer_for reader "$(no_question_form keep-all)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "${ladder_challenges[0]}")" ]
  [ "$(jq -c '.challenge' "$record_file")" = null ]
  answer_for reader "$(rung_form five)"
  run_gate true
  run_gate true
  [ "$(message)" = "$(gate_held_note "Five retries or ten?" five 3 "$(gate_trial_line defaults)"$'\n'"$(gate_kept_line)")" ]
}

@test "a preset whose ladder does not hold its two challenges goes to the operator" {
  ladder_file="$preset_dir/challenges/challenge-ladder.md"
  printf -- '---\nsummary: Ladder.\n---\n\n2. Then:\n   > Clean?\n3. Then: "Sure?"\n' >"$ladder_file"
  run_gate
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_broken_note "$(refuse_ladder_challenges_note "$ladder_file" 2 1)")" ]
  rm "$ladder_file"
  run_gate
  [ "$(message)" = "$(gate_broken_note "$(refuse_unreadable_file_note "$ladder_file")")" ]
}

@test "the ladder's challenges count toward the send-back limit" {
  answer_for reader '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"","claims_done":false,"guidance_answer":""}'
  run_gate false
  run_gate true
  answer_for reader "$(rung_form five)"
  run_gate true
  [ "$(reason)" = "$(gate_challenge_note "${ladder_challenges[0]}")" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 3 ]
  run_gate true
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_operator_note "Five retries or ten?" "$(gate_loop_line 3 "$(gate_challenge_note "${ladder_challenges[1]}")")")" ]
  [ "$(jq -c '.ladder' "$record_file")" = null ]
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
  [ "$(jq '.ladder.answers | length' "$record_file")" -eq 1 ]
  rm "$FAKE_CALLS"
  run_gate false
  [ "$(reason)" = "$(gate_challenge_note "${ladder_challenges[0]}")" ]
  [ "$(calls)" = "$(all_three)" ]
  [ "$(jq '.ladder.answers | length' "$record_file")" -eq 1 ]
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
  [ "$status" -eq 0 ]
  [ "$(message)" = "$(gate_operator_note "Five retries or ten?" "$(gate_loop_line 3 "$(gate_no_recommendation_note)")")" ]
  [ "$(jq '.sent_back' "$record_file")" -eq 0 ]
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

