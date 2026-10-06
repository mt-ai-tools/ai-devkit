bats_require_minimum_version 1.5.0

# Behavior tests for the answer hook: silent where the stand-in is off; where
# it is on, the prompt kept as the answer to the session's last question;
# and, where it cannot be kept, one line for the model with the turn let
# through.

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
