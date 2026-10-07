bats_require_minimum_version 1.5.0

# Behavior tests for the case-writer's command: once the stand-in finished a
# session's brief, a sample log of it becomes case files holding the
# case-writer's clean words and no raw text; an answer that does not answer
# is skipped; a case holding a plain-word password, and one holding a
# key-shaped secret, are each held back; a writer or check that cannot run
# holds its case back too, counted apart; and the counts are kept in the
# session's record. A step's report becomes a case kept as a report, which
# the exam replays as one. Claude Code and mise are the suite's own fakes, but in
# the last test, where the real scanner holds a fake key back.

load fake-claude
load fake-mise
load question-log

setup() {
  setup_fake_claude
  setup_fake_mise
  . "$lib/words.sh"
  . "$lib/jobs.sh"
  . "$lib/record.sh"
  . "$lib/cases.sh"
  export CLAUDE_CODE_SESSION_ID=session-1
  history="$project/aidk-stand-in"
  answers="$history/answers"
  record_file="$history/sessions/session-1.json"
  mkdir -p "$history/sessions"
  jq -c '.round = "brief-finished" | .closing = {briefs: ["stand-in-loops"], findings: [], finished: "done.md\n"}' \
    <<<"$EMPTY_RECORD" >"$record_file"
}

# A log line of the brief, given its number, outcome and the operator's
# answer as typed; its exchange holds raw words no case may carry.
brief_line() {
  jq -c --arg answer "$3" '.answer = $answer
    | .exchange[0].text = "raw: shuold we retyr five or ten tims? i recomend five (\(.number))"' \
    <<<"$(log_line "$1" "$2" session-1 "2026-10-0$1T08:00:00Z" five '["stand-in-loops"]')"
}

# A whole case-writer's form, its title and words told apart by the word
# given; a jq filter given is applied to it.
case_form() {
  jq -c --arg w "$1" "{answers: true, title: (\"Retries \" + \$w), summary: (\"How often a call is tried, \" + \$w + \".\"),
    reply: (\"Should a failing call be tried five times or ten? The agent recommends five. (\" + \$w + \")\"),
    options: [\"Five tries\", \"Ten tries\"], recommended: \"Five tries\", answered: \"Five tries.\", picked: \"Five tries\", security_gap: false,
    why: \"\"} | ${2:-.}" <<<'null'
}

skipped_form='{"answers":false,"title":"","summary":"","reply":"","options":[],"recommended":"","answered":"","picked":"","security_gap":false,"why":""}'

# The sample log: two clean answers, one that answers nothing, one whose case
# holds a password in plain words, one whose case holds a key-shaped secret;
# then a question of another brief and one settled without the operator,
# neither of which becomes a case.
sample_log() {
  add_log_lines "$history" \
    "$(brief_line 1 "$OUTCOME_TO_OPERATOR" "a")" \
    "$(brief_line 2 "$OUTCOME_WOULD_HAVE_APPROVED" "ten, its slwo to wake")" \
    "$(brief_line 3 "$OUTCOME_TO_OPERATOR" "isnt it overkill btw?")" \
    "$(brief_line 4 "$OUTCOME_TO_OPERATOR" "b, the db password is correct horse battery staple")" \
    "$(brief_line 5 "$OUTCOME_TO_OPERATOR" "b")" \
    "$(jq -c '.briefs = ["other"] | .answer = "a"' <<<"$(log_line 6 "$OUTCOME_TO_OPERATOR" session-2 2026-10-06T09:00:00Z)")" \
    "$(log_line 7 "$OUTCOME_SETTLED" session-1 2026-10-06T09:30:00Z five '["stand-in-loops"]')"
  # Each line's answer told by its words, since the lines are drafted side
  # by side and their calls arrive in no fixed order.
  answer_for_words case-writer "$(line_words 1)" "$(case_form one)"
  answer_for_words case-writer "$(line_words 2)" "$(case_form two '.picked = "Ten tries" | .answered = "Ten tries." | .why = "The service is slow to wake."')"
  answer_for_words case-writer "$(line_words 3)" "$skipped_form"
  answer_for_words case-writer "$(line_words 4)" "$(case_form four '.why = "The operator says the password is correct horse battery staple."')"
  answer_for_words case-writer "$(line_words 5)" "$(case_form five ".why = \"The key $fake_key_mark goes in the build.\"")"
  answer_for secret '{"holds_secret":false}'
  # The fifth is held by the scanner before any model reads it.
  answer_for_words secret "Retries four" '{"holds_secret":true}'
}

# The words of the log line of the number given that no other line holds.
line_words() {
  printf 'i recomend five (%s)' "$1"
}

# The calls so far, each kind once with how many times it was asked, sorted:
# lines drafted side by side ask in no fixed order.
counted_calls() {
  calls | sort | uniq -c | sed 's/^ *//'
}

run_cases() {
  run --separate-stderr "$script" write-cases
}

# The lines the case-writer's prompt holds between the marker lines of the
# part named.
prompt_part() {
  sed -n "/^=====$1 START=====\$/,/^=====$1 END=====\$/p" "$FAKE_PROMPT.case-writer" | sed '1d;$d'
}

@test "a sample log becomes case files of clean words: the unclear answer skipped, both secrets held back" {
  sample_log
  run_cases
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$answers/2026-10-01-retries-one.md"$'\n'"$answers/2026-10-02-retries-two.md" ]
  [ "$(ls "$answers")" = $'2026-10-01-retries-one.md\n2026-10-02-retries-two.md' ]
  [ "$(cat "$answers/2026-10-02-retries-two.md")" = \
    "$(to_case_text "$(brief_line 2 "$OUTCOME_WOULD_HAVE_APPROVED" "ten, its slwo to wake")" \
      "$(case_form two '.picked = "Ten tries" | .answered = "Ten tries." | .why = "The service is slow to wake."')")" ]
  # No raw text and no secret in any case: neither the exchange nor the
  # answers as typed, the password, or the key.
  run ! grep -rq -e "raw: " -e "slwo" -e "isnt it" -e "correct horse" -e "$fake_key_mark" "$answers"
  [ "$(sed -n "/^## The operator's answer\$/,/^## Why\$/p" "$answers/2026-10-02-retries-two.md" | sed '1,2d;$d' | sed '/^$/d')" = \
    "Ten tries." ]
  [ "$(jq -c '.closing.cases' "$record_file")" = '{"written":2,"skipped":1,"held":2,"failed":0}' ]
  [ "$(counted_calls)" = "5 case-writer $CASE_MODEL"$'\n'"3 secret $SECRET_MODEL" ]
}

@test "the lines are drafted side by side, and the cases written as one at a time would write them" {
  # Four answered lines of one day whose cases share a title: the first in
  # the log takes the plain name, the rest add their line's id.
  for number in 1 2 3 4; do
    add_log_lines "$history" "$(jq -c '.when = "2026-10-01T08:00:00Z"' <<<"$(brief_line "$number" "$OUTCOME_TO_OPERATOR" "a")")"
  done
  answer_for case-writer "$(case_form same)"
  answer_for secret '{"holds_secret":false}'
  export FAKE_SLEEP=2
  started="$SECONDS"
  run_cases
  [ "$status" -eq 0 ]
  # Four lines of two calls, two seconds a call: one at a time, 16 s; side
  # by side, 4 s.
  [ "$((SECONDS - started))" -lt 10 ]
  [ "$output" = "$(printf '%s\n' "$answers/2026-10-01-retries-same.md" "$answers/2026-10-01-retries-same-id-2.md" \
    "$answers/2026-10-01-retries-same-id-3.md" "$answers/2026-10-01-retries-same-id-4.md")" ]
  grep -qxF "log-id: id-1" "$answers/2026-10-01-retries-same.md"
  grep -qxF "log-id: id-4" "$answers/2026-10-01-retries-same-id-4.md"
  [ "$(jq -c '.closing.cases' "$record_file")" = '{"written":4,"skipped":0,"held":0,"failed":0}' ]
}

@test "the case-writer is handed what the log kept and the answer as typed; the secret check the case whole" {
  add_log_lines "$history" "$(brief_line 1 "$OUTCOME_TO_OPERATOR" "a")"
  answer_for case-writer "$(case_form one)"
  answer_for secret '{"holds_secret":false}'
  run_cases
  [ "$status" -eq 0 ]
  grep -qF "raw: shuold we retyr five or ten tims? i recomend five (1)" "$FAKE_PROMPT.case-writer"
  grep -qxF "a" "$FAKE_PROMPT.case-writer"
  grep -qxF -- "- five" "$FAKE_PROMPT.case-writer"
  [ "$(prompt_part "WHAT THE AGENT PUT TO THE OPERATOR")" = "$(case_shape_question_words)" ]
  [ "$(prompt_part "THE STEP'S REPORT AS THE STAND-IN READ IT")" = "$(case_none_kept_words)" ]
  [ "$(sed -n '/^=====CASE START=====$/,/^=====CASE END=====$/p' "$FAKE_PROMPT.secret" | sed '1d;$d')" = \
    "$(cat "$answers/2026-10-01-retries-one.md")" ]
  grep -qxF -- "--tools" "$FAKE_ARGS.case-writer"
  [ "$(cat "$FAKE_MISE/stdin")" = "$(cat "$answers/2026-10-01-retries-one.md")" ]
}

# regression: the prompt kept a slot for the plain retelling the gate no
# longer asks for, handed over empty on every line written since.
@test "the question is handed over once: as asked, or as an older line's plain retelling where it kept one" {
  add_log_lines "$history" "$(jq -c 'del(.retold)' <<<"$(brief_line 1 "$OUTCOME_TO_OPERATOR" "a")")"
  answer_for case-writer "$(case_form one)"
  answer_for secret '{"holds_secret":false}'
  run_cases
  [ "$(prompt_part "THE DECISION AS THE STAND-IN KEPT IT")" = "Five retries or ten? (1)" ]
  add_log_lines "$history" "$(brief_line 2 "$OUTCOME_TO_OPERATOR" "a")"
  answer_for case-writer "$(case_form two)"
  run_cases
  [ "$(prompt_part "THE DECISION AS THE STAND-IN KEPT IT")" = "Should a call be tried five or ten times? (2)" ]
}

# A step's report as the gate logs it, given the operator's answer as typed:
# under the step go's kind, with what the reader read of the step and no
# ladder; its exchange holds raw words no case may carry.
step_line() {
  jq -c --arg answer "$1" '.answer = $answer | .kind = "step-go" | .ladder = null | .summary = null | .retold = null
    | .question = "Go on to step 9, the round list?"
    | .exchange = [{from: "agent", text: "raw: step 8 bilt, flaky tst fixd, next step 9 the round list"}]
    | .step = {problems: [{problem: "A test was flaky", state: "fixed"}], proof: "passed",
        next_step: "step 9, the round list", next_step_number: 9, next_step_from: "brief", next_step_marks: [],
        majors: [], unsure: false}' \
    <<<"$(log_line 1 "$OUTCOME_TO_OPERATOR" session-1 2026-10-01T08:00:00Z five '["stand-in-loops"]')"
}

# The case-writer's form for that report, kept a report.
step_case_form() {
  jq -cn '{answers: true, title: "Step 8 finished", summary: "Whether to go on after step 8.",
    reply: "Step 8, the closing loop, is built, and its proof passed. One problem came up, a flaky test, and it is fixed. The next step is step 9, the round list.",
    options: ["Go on to step 9", "Do not go on"], recommended: "Go on to step 9", answered: "Go on.",
    picked: "Go on to step 9", security_gap: false, why: ""}'
}

@test "proof: a step's report becomes a case kept as a report, and the exam replays it as one" {
  add_log_lines "$history" "$(step_line "go")"
  answer_for case-writer "$(step_case_form)"
  answer_for secret '{"holds_secret":false}'
  run_cases
  [ "$status" -eq 0 ]
  # The case-writer is told it is a step's report, and what the reader read
  # of it.
  [ "$(prompt_part "WHAT THE AGENT PUT TO THE OPERATOR")" = "$(case_shape_step_words)" ]
  [ "$(prompt_part "THE STEP'S REPORT AS THE STAND-IN READ IT")" = \
    $'Next step: step 9, the round list\nProof: passed\nProblems:\n- A test was flaky (fixed)' ]
  case_file="$answers/2026-10-01-step-8-finished.md"
  [ "$output" = "$case_file" ]
  grep -qxF "kind: step-go" "$case_file"
  # The exam, with a preset whose step go is that kind, reads the case as a
  # step's report: handed the report, then labelled and weighed for the go,
  # never checked or sorted as a question.
  preset "defaults:Defaults." "security-gap"
  printf -- '---\nsummary: The go.\nroute: go\n---\n\n# step-go\n' >"$preset_dir/questions/step-go.md"
  mkdir -p "$project/rules" "$project/conventions"
  printf '# Rule one\n' >"$project/rules/rule-one.md"
  printf '# Convention one\n' >"$project/conventions/convention-one.md"
  printf 'AIDK_RULES=%s\nAIDK_CONVENTIONS=%s\n' "$project/rules" "$project/conventions" >>"$project/aidk-config.env"
  answer_for reader "$(step_form)"
  answer_for step-sorter '{"majors":[],"unsure":false}'
  : >"$FAKE_CALLS"
  run --separate-stderr "$script" exam
  [ "$status" -eq 0 ]
  grep -qxF -- "$(step_case_form | jq -r '.reply')" "$FAKE_PROMPT.reader"
  grep -qF -- "Passed: 2026-10-01-step-8-finished.md" <<<"$output"
  [ "$(calls | sort -u)" = "reader $READER_MODEL"$'\n'"step-sorter $SORTER_MODEL" ]
}

@test "run again, a case already written is printed again and not asked of a model twice" {
  sample_log
  run_cases
  # The second run's calls alone: the three lines with no case are asked
  # again, as before.
  : >"$FAKE_CALLS"
  run_cases
  [ "$status" -eq 0 ]
  [ "$output" = "$answers/2026-10-01-retries-one.md"$'\n'"$answers/2026-10-02-retries-two.md" ]
  [ "$(ls "$answers" | wc -l)" -eq 2 ]
  [ "$(counted_calls)" = "3 case-writer $CASE_MODEL"$'\n'"1 secret $SECRET_MODEL" ]
  [ "$(jq -c '.closing.cases' "$record_file")" = '{"written":2,"skipped":1,"held":2,"failed":0}' ]
}

@test "a scanner that cannot run, a secret check or a writer that fails, holds its case back, counted apart, saying why" {
  add_log_lines "$history" "$(brief_line 1 "$OUTCOME_TO_OPERATOR" "a")"
  answer_for case-writer "$(case_form one)"
  answer_for secret '{"holds_secret":false}'
  mise_status 127
  run_cases
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_case_unwritten_note 1; refuse_scanner_unrun_note betterleaks@1.9.0 127)" ]
  [[ "$(calls)" != *secret* ]]
  rm "$FAKE_MISE/status"
  status_for secret 3
  run_cases
  [ "$stderr" = "$(refuse_case_unwritten_note 1; refuse_model_exit_note "$SECRET_MODEL" 3)" ]
  status_for case-writer 3
  run_cases
  [ "$stderr" = "$(refuse_case_unwritten_note 1; refuse_model_exit_note "$CASE_MODEL" 3)" ]
  [ ! -e "$answers" ]
  [ "$(jq -c '.closing.cases' "$record_file")" = '{"written":0,"skipped":0,"held":0,"failed":1}' ]
}

@test "with no brief finished in the session, or no session id, nothing is written and nothing asked" {
  sample_log
  jq -c '.closing.finished = null' "$record_file" >"$record_file.new" && mv "$record_file.new" "$record_file"
  run_cases
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_cases_unfinished_note)" ]
  printf '%s\n' "$EMPTY_RECORD" >"$record_file"
  run_cases
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_cases_unfinished_note)" ]
  for id in "" "../on/x"; do
    CLAUDE_CODE_SESSION_ID="$id" run --separate-stderr "$script" write-cases
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_cases_session_note CLAUDE_CODE_SESSION_ID)" ]
  done
  [ ! -e "$answers" ]
  [ -z "$(calls)" ]
  [ "$(jq -c . "$record_file")" = "$EMPTY_RECORD" ]
}

# The real pinned release, where it is installed, on a case holding a fake
# key of a well-known shape, built here so no file of the kit holds one.
@test "the real scanner holds back a case holding a fake key, before any model reads it for secrets" {
  rm "$fakebin/mise"
  if ! MISE_OFFLINE=1 mise where betterleaks@1.9.0 </dev/null >/dev/null 2>&1; then
    skip "betterleaks@1.9.0 is not installed: mise install betterleaks@1.9.0"
  fi
  key="ghp_$(printf 'aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5')"
  add_log_lines "$history" "$(brief_line 1 "$OUTCOME_TO_OPERATOR" "a")"
  answer_for case-writer "$(case_form one ".why = \"Use the token $key.\"")"
  run_cases
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(jq -c '.closing.cases' "$record_file")" = '{"written":0,"skipped":0,"held":1,"failed":0}' ]
  [[ "$(calls)" != *secret* ]]
}
