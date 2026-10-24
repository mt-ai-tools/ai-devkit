bats_require_minimum_version 1.5.0

# Behavior tests for the size hook: a builder past its line gets the note,
# again on each tool, a short builder, another agent and the session get
# nothing, and a builder whose transcript is missing is reported, not passed.

setup() {
  hook="$BATS_TEST_DIRNAME/../hooks/size-hook.sh"
  . "$BATS_TEST_DIRNAME/../lib/words.sh"
  sessions="$BATS_TEST_TMPDIR/project"
  mkdir -p "$sessions/s1/subagents"
  agent_transcript="$sessions/s1/subagents/agent-a1.jsonl"
  : >"$agent_transcript"
}

# One reply of the agent, carrying a context of the size given.
reply() {
  printf '{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":%s}}}\n' "$1" >>"$agent_transcript"
}

# An after-tool event from the agent of the type given, or from the session
# where none is given.
event() {
  if [ -n "${1:-}" ]; then
    printf '{"session_id":"s1","transcript_path":"%s/s1.jsonl","agent_id":"a1","agent_type":"%s","tool_name":"Bash"}' "$sessions" "$1"
  else
    printf '{"session_id":"s1","transcript_path":"%s/s1.jsonl","tool_name":"Bash"}' "$sessions"
  fi
}

@test "a builder past the line is told it has grown long, with its size" {
  reply 120000
  reply 250000
  run --separate-stderr bash -c "printf '%s' '$(event builder)' | '$hook'"
  [ "$status" -eq 0 ]
  [ "$(jq -r .hookSpecificOutput.additionalContext <<<"$output")" = "$(size_hook_long_note 250000)" ]
  [ "$(jq -r .hookSpecificOutput.hookEventName <<<"$output")" = "PostToolUse" ]
}

@test "the note comes again on the next tool while the builder is still long" {
  reply 250000
  run bash -c "printf '%s' '$(event builder)' | '$hook'"
  reply 260000
  run bash -c "printf '%s' '$(event builder)' | '$hook'"
  [ "$(jq -r .hookSpecificOutput.additionalContext <<<"$output")" = "$(size_hook_long_note 260000)" ]
}

@test "a builder exactly at the line is told nothing" {
  reply 200000
  run bash -c "printf '%s' '$(event builder)' | '$hook'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "another agent past the line is told nothing" {
  reply 250000
  run bash -c "printf '%s' '$(event reviewer)' | '$hook'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the session's own tools are told nothing" {
  run bash -c "printf '%s' '$(event)' | '$hook'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a builder with no transcript is reported to the operator, not passed as short" {
  rm "$agent_transcript"
  run --separate-stderr bash -c "printf '%s' '$(event builder)' | '$hook'"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(size_hook_no_transcript_note "$agent_transcript")" ]
}
