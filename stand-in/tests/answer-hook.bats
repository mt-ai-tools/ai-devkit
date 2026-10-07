bats_require_minimum_version 1.5.0

# Behavior tests for the answer hook: silent where the stand-in is off; where
# it is on, the prompt kept as the answer to the session's last question,
# never a typed command; and, where it cannot be kept, one line for the model
# with the turn let through.

load fake-claude
load question-log

setup() {
  setup_fake_claude
  hook="$BATS_TEST_DIRNAME/../hooks/answer-hook.sh"
  . "$lib/words.sh"
  . "$lib/question-log.sh"
  history="$project/aidk-stand-in"
  file="$history/log/questions.jsonl"
  add_log_lines "$history" "$(log_line 1 "$OUTCOME_TO_OPERATOR" session-1 2026-10-06T10:00:00Z)"
}

teardown() {
  [ ! -d "$history/log" ] || chmod u+rwx "$history/log"
}

# A turn's event, as Claude Code hands it to a prompt hook.
turn_event() {
  jq -cn --arg session "$1" --arg prompt "$2" '{session_id: $session, hook_event_name: "UserPromptSubmit", prompt: $prompt}'
}

run_hook() {
  run --separate-stderr "$hook" <<<"$1"
}

@test "a session the stand-in is off for is left alone: nothing said, nothing written" {
  cp "$file" "$BATS_TEST_TMPDIR/before"
  run_hook "$(turn_event session-1 "Five.")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  cmp "$file" "$BATS_TEST_TMPDIR/before"
}

@test "where the stand-in is on, the prompt is kept as the answer, and nothing is said" {
  mkdir -p "$history/on"
  : >"$history/on/session-1"
  run_hook "$(turn_event session-1 "Five, but log every retry.")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(jq -r '.answer' "$file")" = "Five, but log every retry." ]
}

@test "a typed command is never kept as the answer: the next prompt that is not one is" {
  mkdir -p "$history/on"
  : >"$history/on/session-1"
  for command in "/devkit-stand-in file-trash" "/clear"; do
    run_hook "$(turn_event session-1 "$command")"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(jq -r '.answer' "$file")" = "" ]
  done
  run_hook "$(turn_event session-1 "Ten, and see /tmp for why.")"
  [ "$(jq -r '.answer' "$file")" = "Ten, and see /tmp for why." ]
}

@test "an answer that cannot be kept is one line for the model, and the turn goes on" {
  mkdir -p "$history/on"
  : >"$history/on/session-1"
  chmod a-w "$history/log"
  run_hook "$(turn_event session-1 "Five.")"
  [ "$status" -eq 0 ]
  [ "$output" = "$(answer_unrecorded_note "$(refuse_log_unwritable_note "$history/log")")" ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 1 ]
}

@test "an event with no session id it can use is one line for the model, and the turn goes on" {
  run_hook '{"session_id":"../escape","prompt":"Five."}'
  [ "$status" -eq 0 ]
  [ "$output" = "$(answer_unrecorded_note "$(refuse_prompt_session_note)")" ]
}

# The question whether a kind may answer alone, as the gate logs it under an
# end report, waiting for the answer; given its number and the kind.
trust_line() {
  jq -c --arg kind "$2" '.trust = {kind: $kind, score: {tries: 20, agreed: 19, misses: []}} | .kind = null' \
    <<<"$(log_line "$1" "$OUTCOME_TO_OPERATOR" session-1 2026-10-07T10:00:00Z "")"
}

switched_on() {
  mkdir -p "$history/on"
  : >"$history/on/session-1"
}

@test "proof: a plain yes to the question whether a kind may answer alone keeps the kind's yes file, and tells both the operator and the agent" {
  . "$lib/trial.sh"
  switched_on
  add_log_lines "$history" "$(trust_line 2 whole)"
  run_hook "$(turn_event session-1 " Yes. ")"
  [ "$status" -eq 0 ]
  yes_file="$history/trusted/whole.md"
  [ "$(jq -r '.systemMessage' <<<"$output")" = "$(trust_given_note whole "$yes_file")" ]
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")" = "$(trust_given_agent_note whole "$yes_file")" ]
  [ "$(tail -n 1 "$file" | jq -r '.answer')" = " Yes. " ]
  [ "$(sed -n 2p "$yes_file")" = "kind: whole" ]
  [[ "$(sed -n 3p "$yes_file")" =~ ^given:\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
  ! is_on_trial "$history" whole
  # Answered once, the question takes no later prompt: a second yes keeps
  # nothing, and the file stands as the first yes wrote it.
  cp "$yes_file" "$BATS_TEST_TMPDIR/first"
  run_hook "$(turn_event session-1 "yes")"
  [ -z "$output" ]
  cmp "$yes_file" "$BATS_TEST_TMPDIR/first"
}

@test "anything but a plain yes leaves the kind on trial: kept as the answer, and no file written" {
  switched_on
  for answer in "yes, but only for small ones" "no" "Sure" "yes please"; do
    rm -f "$file"
    add_log_lines "$history" "$(trust_line 2 whole)"
    run_hook "$(turn_event session-1 "$answer")"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(jq -r '.answer' "$file")" = "$answer" ]
    [ ! -e "$history/trusted" ]
  done
  # A yes to a question that is not the trial's switches nothing.
  rm -f "$file"
  add_log_lines "$history" "$(log_line 3 "$OUTCOME_TO_OPERATOR" session-1 2026-10-07T10:00:00Z)"
  run_hook "$(turn_event session-1 "yes")"
  [ -z "$output" ]
  [ ! -e "$history/trusted" ]
}

@test "a yes that cannot be kept tells the operator the kind stays on trial, and the agent to commit nothing" {
  switched_on
  add_log_lines "$history" "$(trust_line 2 whole)"
  mkdir -p "$history/trusted"
  chmod a-w "$history/trusted"
  run_hook "$(turn_event session-1 "yes")"
  chmod u+w "$history/trusted"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.systemMessage' <<<"$output")" = "$(trust_unkept_note whole "$(refuse_trust_unwritable_note "$history/trusted")")" ]
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")" = "$(trust_unkept_agent_note whole)" ]
  [ ! -e "$history/trusted/whole.md" ]
}
