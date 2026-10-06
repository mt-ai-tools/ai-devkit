bats_require_minimum_version 1.5.0

# Behavior tests for the question hook: in a session the stand-in is on for,
# the question box is refused and the agent told, in the stand-in's words, to
# ask in its reply; in a session it is off for, the box runs as before,
# silently; another tool is never touched; and where whether the stand-in is
# on cannot be told, the box is let through and the operator told why.

load fake-claude

setup() {
  setup_fake_claude
  hook="$BATS_TEST_DIRNAME/../hooks/question-hook.sh"
  . "$lib/words.sh"
  history="$project/aidk-stand-in"
  mkdir -p "$history/on"
  : >"$history/on/session-1"
}

teardown() {
  [ ! -d "$history" ] || chmod -R u+rwx "$history"
}

# A before-tool event, as Claude Code hands it to the hook, for the session
# and tool named. Claude Code's own name for its question tool is spelled
# here, since Claude Code, not the stand-in, fixes it.
tool_event() {
  jq -cn --arg session "$1" --arg tool "$2" '{
    session_id: $session, hook_event_name: "PreToolUse", tool_name: $tool,
    tool_input: {questions: [{question: "Tea or coffee?", header: "Drink",
      options: [{label: "Tea", description: "Leaves."}, {label: "Coffee", description: "Beans."}],
      multiSelect: false}]}
  }'
}

run_hook() {
  run --separate-stderr "$hook" <<<"$1"
}

@test "in a session the stand-in is on for, the question box is refused with the stand-in's words" {
  run_hook "$(tool_event session-1 AskUserQuestion)"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$output")" = "PreToolUse" ]
  [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$output")" = "deny" ]
  [ "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$output")" = \
    "$(question_box_refused_note AskUserQuestion)" ]
  [[ "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$output")" == "From the stand-in: "* ]]
}

@test "in a session the stand-in is off for, the question box runs as before, silently" {
  run_hook "$(tool_event session-2 AskUserQuestion)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "in a project the stand-in was never switched on in, the question box runs, silently" {
  rm -r "$history"
  run_hook "$(tool_event session-1 AskUserQuestion)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "another tool, in a session the stand-in is on for, is untouched" {
  run_hook "$(tool_event session-1 Bash)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "a switch folder that cannot be searched lets the box through and tells the operator why" {
  rm -r "$history/on"
  : >"$history/on"
  run_hook "$(tool_event session-1 AskUserQuestion)"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.systemMessage' <<<"$output")" = \
    "$(question_box_unjudged_note "$(refuse_switch_unknown_note "$history/on")")" ]
  [ "$(jq 'has("hookSpecificOutput")' <<<"$output")" = false ]
}

@test "the question box with no session id it can use is let through, the operator told why" {
  for event in '{"tool_name":"AskUserQuestion"}' '{"tool_name":"AskUserQuestion","session_id":"../on/session-1"}'; do
    run_hook "$event"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.systemMessage' <<<"$output")" = "$(question_box_unjudged_note "$(refuse_tool_session_note)")" ]
    [ "$(jq 'has("hookSpecificOutput")' <<<"$output")" = false ]
  done
}

@test "an event that is not JSON is let go silently, since no tool can be told from it" {
  run_hook 'not json'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
