bats_require_minimum_version 1.5.0

# Behavior tests for the workflow's two agent hooks: an agent that reports
# once is refused more work after it ends, while one still running, one
# stopped only to wait for a background shell command, one of another kind,
# and an agent of another session are not.

setup() {
  end_hook="$BATS_TEST_DIRNAME/../hooks/agent-end-hook.sh"
  message_hook="$BATS_TEST_DIRNAME/../hooks/message-hook.sh"
  . "$BATS_TEST_DIRNAME/../lib/words.sh"
  export TMPDIR="$BATS_TEST_TMPDIR"
}

# The agent-end event for an agent of the type given, in the session given.
ended() {
  printf '{"hook_event_name":"SubagentStop","session_id":"%s","agent_id":"%s","agent_type":"%s"}' "$1" "$2" "$3" |
    "$end_hook"
}

# The session's attempt to message an agent; the hook's answer is the output.
message() {
  run --separate-stderr bash -c "printf '%s' '{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$1\",\"tool_name\":\"SendMessage\",\"tool_input\":{\"to\":\"$2\",\"message\":\"one more\"}}' | '$message_hook'"
}

@test "a builder that has reported is refused more work, with the reason" {
  ended s1 a1 builder
  message s1 a1
  [ "$status" -eq 0 ]
  [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$output")" = "deny" ]
  [ "$(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$output")" = "$(finished_agent_note a1)" ]
}

@test "a fixer, a reviewer and the brief writer that have reported are refused too" {
  ended s1 f1 fixer
  ended s1 r1 reviewer
  ended s1 w1 brief-writer
  for agent in f1 r1 w1; do
    message s1 "$agent"
    [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$output")" = "deny" ]
  done
}

@test "an agent still running may be messaged" {
  ended s1 a1 builder
  message s1 a2
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# The agent-end event for a builder that stops while the session lists the
# background tasks given, as Claude Code writes them: the agent itself among
# them, and shell commands with no owner.
ended_with_tasks() {
  printf '{"hook_event_name":"SubagentStop","session_id":"s1","agent_id":"a1","agent_type":"builder","background_tasks":%s}' "$1" |
    "$end_hook"
}

# regression: a builder that stopped only to wait for its own background shell command was refused the message that resumed it.
@test "an agent that stops while a shell command runs in the background may be messaged" {
  ended_with_tasks '[{"id":"a1","type":"subagent","status":"running"},{"id":"b1","type":"shell","status":"running","command":"sleep 20"}]'
  message s1 a1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an agent that stops with only finished shell commands and running agents listed is refused" {
  ended_with_tasks '[{"id":"a1","type":"subagent","status":"running"},{"id":"b1","type":"shell","status":"completed","command":"sleep 20"}]'
  message s1 a1
  [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$output")" = "deny" ]
}

@test "an agent of another kind may be messaged after it reports" {
  ended s1 g1 general-purpose
  message s1 g1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an agent another session finished is not refused here" {
  ended s1 a1 builder
  message s2 a1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a session id that is not plainly a name is reported, and nothing is written" {
  run --separate-stderr bash -c "printf '%s' '{\"session_id\":\"../x\",\"agent_id\":\"a1\",\"agent_type\":\"builder\"}' | '$end_hook'"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(bad_session_note ../x)" ]
  [ ! -e "$BATS_TEST_TMPDIR/x" ]
}
