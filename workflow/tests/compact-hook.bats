bats_require_minimum_version 1.5.0

# Behavior tests for the compact note: the last reply of the main
# conversation decides, past the line the session is told and short of it
# nothing is said, a subagent's turn and a half-written line are passed over,
# a reply buried under a large later line is still found, and an event naming
# no transcript is told to the operator without stopping the turn.

setup() {
  hook="$BATS_TEST_DIRNAME/../hooks/compact-hook.sh"
  . "$BATS_TEST_DIRNAME/../lib/words.sh"
  . "$BATS_TEST_DIRNAME/../../lib/readers/transcript.sh"
  transcript="$BATS_TEST_TMPDIR/session.jsonl"
  : >"$transcript"
}

# One reply of the main conversation, carrying a context of the size given,
# split across the three parts a reply's usage reports.
reply() {
  local third=$(($1 / 3))
  printf '{"type":"assistant","message":{"usage":{"input_tokens":%s,"cache_read_input_tokens":%s,"cache_creation_input_tokens":%s}}}\n' \
    "$third" "$third" "$(($1 - 2 * third))" >>"$transcript"
}

subagent_reply() {
  printf '{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":%s}}}\n' "$1" >>"$transcript"
}

# The turn-start event for the transcript given; the hook's answer is the
# output.
turn() {
  run --separate-stderr bash -c "printf '%s' '{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"s1\",\"transcript_path\":\"$1\",\"prompt\":\"hi\"}' | '$hook'"
}

@test "a session past the line is told, with its size" {
  reply 120000
  reply 300000
  turn "$transcript"
  [ "$status" -eq 0 ]
  [ "$output" = "$(compact_hook_note 300000)" ]
}

@test "a session short of the line is told nothing" {
  reply 150000
  turn "$transcript"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the last reply decides, so a compacted session is told nothing again" {
  reply 400000
  reply 30000
  turn "$transcript"
  [ -z "$output" ]
}

@test "a session exactly at the line is told nothing" {
  reply 200000
  turn "$transcript"
  [ -z "$output" ]
}

@test "a session one past the line is told" {
  reply 200001
  turn "$transcript"
  [ "$output" = "$(compact_hook_note 200001)" ]
}

@test "a subagent's turn is left out" {
  reply 100000
  subagent_reply 900000
  turn "$transcript"
  [ -z "$output" ]
}

@test "a half-written last line is passed over" {
  reply 260000
  printf '{"type":"assistant","message":{"usa' >>"$transcript"
  turn "$transcript"
  [ "$status" -eq 0 ]
  [ "$output" = "$(compact_hook_note 260000)" ]
}

@test "a reply followed by more than the end that is read first is still found" {
  reply 270000
  head -c "$((TRANSCRIPT_TAIL_BYTES + 1000))" /dev/zero | tr '\0' 'x' >>"$transcript"
  printf '\n' >>"$transcript"
  turn "$transcript"
  [ "$output" = "$(compact_hook_note 270000)" ]
}

@test "a session with no transcript written yet is told nothing" {
  turn "$BATS_TEST_TMPDIR/not-yet.jsonl"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "an event naming no transcript is told to the operator without stopping the turn" {
  run --separate-stderr bash -c "printf '%s' '{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"s1\"}' | '$hook'"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(compact_hook_no_transcript_note)" ]
}
