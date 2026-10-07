bats_require_minimum_version 1.5.0

# Behavior tests for the case-writer's command: once the stand-in finished a
# session's brief, a sample log of it becomes case files holding the
# case-writer's clean words and no raw text; an answer that does not answer
# is skipped; a case holding a plain-word password, and one holding a
# key-shaped secret, are each held back; a writer or check that cannot run
# holds its case back too, counted apart; and the counts are kept in the
# session's record. Claude Code and mise are the suite's own fakes, but in
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
    options: [\"Five tries\", \"Ten tries\"], recommended: \"Five tries\", answered: \"Five tries.\", picked: \"Five tries\",
    why: \"\"} | ${2:-.}" <<<'null'
}

skipped_form='{"answers":false,"title":"","summary":"","reply":"","options":[],"recommended":"","answered":"","picked":"","why":""}'

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
  answer_for_call case-writer 1 "$(case_form one)"
  answer_for_call case-writer 2 "$(case_form two '.picked = "Ten tries" | .answered = "Ten tries." | .why = "The service is slow to wake."')"
  answer_for_call case-writer 3 "$skipped_form"
  answer_for_call case-writer 4 "$(case_form four '.why = "The operator says the password is correct horse battery staple."')"
  answer_for_call case-writer 5 "$(case_form five ".why = \"The key $fake_key_mark goes in the build.\"")"
  answer_for secret '{"holds_secret":false}'
  # The secret check's third call is the fourth line's: the fifth is held by
  # the scanner before any model reads it.
  answer_for_call secret 3 '{"holds_secret":true}'
}

run_cases() {
  run --separate-stderr "$script" write-cases
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
  [ "$(calls)" = "$(printf '%s\n' "case-writer $CASE_MODEL" "secret $SECRET_MODEL" "case-writer $CASE_MODEL" \
    "secret $SECRET_MODEL" "case-writer $CASE_MODEL" "case-writer $CASE_MODEL" "secret $SECRET_MODEL" \
    "case-writer $CASE_MODEL")" ]
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
  grep -qF "Should a call be tried five or ten times? (1)" "$FAKE_PROMPT.case-writer"
  [ "$(sed -n '/^=====CASE START=====$/,/^=====CASE END=====$/p' "$FAKE_PROMPT.secret" | sed '1d;$d')" = \
    "$(cat "$answers/2026-10-01-retries-one.md")" ]
  grep -qxF -- "--tools" "$FAKE_ARGS.case-writer"
  [ "$(cat "$FAKE_MISE/stdin")" = "$(cat "$answers/2026-10-01-retries-one.md")" ]
}

@test "run again, a case already written is printed again and not asked of a model twice" {
  sample_log
  run_cases
  first="$(calls | wc -l)"
  # The second run's calls, counted on from the first's: the three lines with
  # no case are asked again, as before.
  answer_for_call case-writer 6 "$skipped_form"
  answer_for_call case-writer 7 "$(case_form four)"
  answer_for_call case-writer 8 "$(case_form five ".why = \"$fake_key_mark\"")"
  answer_for_call secret 4 '{"holds_secret":true}'
  run_cases
  [ "$status" -eq 0 ]
  [ "$output" = "$answers/2026-10-01-retries-one.md"$'\n'"$answers/2026-10-02-retries-two.md" ]
  [ "$(ls "$answers" | wc -l)" -eq 2 ]
  [ "$(calls | tail -n +"$((first + 1))")" = "$(printf '%s\n' "case-writer $CASE_MODEL" "case-writer $CASE_MODEL" \
    "secret $SECRET_MODEL" "case-writer $CASE_MODEL")" ]
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
