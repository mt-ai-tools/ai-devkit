bats_require_minimum_version 1.5.0

# Behavior tests for the session size: the last reply of the main conversation
# decides, past the line it says compact and short of it fine, a subagent's
# turn and a half-written line are passed over, and a session with no id or no
# transcript is refused rather than called fine.

setup() {
  script="$BATS_TEST_DIRNAME/../bin/session-size.sh"
  . "$BATS_TEST_DIRNAME/../lib/words.sh"
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

@test "a session past the line is told to compact, with its size" {
  reply 120000
  reply 300000
  run "$script" "$transcript"
  [ "$status" -eq 0 ]
  [ "$output" = "$(session_size_compact_note 300000)" ]
}

@test "a session short of the line is fine, with its size" {
  reply 180000
  run "$script" "$transcript"
  [ "$status" -eq 0 ]
  [ "$output" = "$(session_size_fine_note 180000)" ]
}

@test "the last reply decides, so a compacted session is fine again" {
  reply 400000
  reply 30000
  run "$script" "$transcript"
  [ "$output" = "$(session_size_fine_note 30000)" ]
}

@test "a session exactly at the line is fine" {
  reply 250000
  run "$script" "$transcript"
  [ "$output" = "$(session_size_fine_note 250000)" ]
}

@test "a subagent's turn is left out" {
  reply 100000
  subagent_reply 900000
  run "$script" "$transcript"
  [ "$output" = "$(session_size_fine_note 100000)" ]
}

@test "a half-written last line is passed over" {
  reply 260000
  printf '{"type":"assistant","message":{"usa' >>"$transcript"
  run "$script" "$transcript"
  [ "$status" -eq 0 ]
  [ "$output" = "$(session_size_compact_note 260000)" ]
}

@test "a session with no reply yet is fine at nothing" {
  run "$script" "$transcript"
  [ "$output" = "$(session_size_fine_note 0)" ]
}

@test "with no transcript given, the session's own is found by its id" {
  config="$BATS_TEST_TMPDIR/config"
  mkdir -p "$config/projects/some-project"
  transcript="$config/projects/some-project/abc-123.jsonl"
  reply 270000
  CLAUDE_CONFIG_DIR="$config" CLAUDE_CODE_SESSION_ID=abc-123 run "$script"
  [ "$status" -eq 0 ]
  [ "$output" = "$(session_size_compact_note 270000)" ]
}

@test "a session with no id is refused" {
  run --separate-stderr env -u CLAUDE_CODE_SESSION_ID "$script"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(session_size_no_session_note CLAUDE_CODE_SESSION_ID)" ]
}

@test "a session whose transcript cannot be found is refused" {
  config="$BATS_TEST_TMPDIR/config"
  mkdir -p "$config/projects"
  CLAUDE_CONFIG_DIR="$config" CLAUDE_CODE_SESSION_ID=missing run --separate-stderr "$script"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(session_size_no_transcript_note missing "$config/projects")" ]
}

@test "more than one argument is refused with the usage" {
  run --separate-stderr "$script" a b
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(session_size_usage_note)" ]
}
