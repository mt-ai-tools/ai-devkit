bats_require_minimum_version 1.5.0

# Behavior tests for the session-end hook: the ending session's marks are
# freed and every other session's stay; an event with no session id frees
# nothing, says why, and lets the session end.

load project

setup() {
  setup_project
  hook="$BATS_TEST_DIRNAME/../hooks/end-hook.sh"
  place aidk-plans
  brief file-trash "Trash." "[]" "[aidk-plans]" "[]"
  brief frozen-account "Frozen." "[]" "[aidk-plans]" "[]"
  brief media-one-bucket "Bucket." "[]" "[aidk-plans]" "[]"
}

# The hook, run on an event.
run_hook() {
  run --separate-stderr bash -c "printf '%s' '$1' | '$hook'"
}

@test "the ending session's marks are freed, and only its own" {
  mark file-trash session-1 "$now"
  mark media-one-bucket session-1 "$now"
  mark frozen-account session-2 "$now"
  run_hook '{"session_id":"session-1","reason":"prompt_input_exit"}'
  [ "$status" -eq 0 ]
  [ ! -e "$marks/file-trash" ]
  [ ! -e "$marks/media-one-bucket" ]
  [ -e "$marks/frozen-account" ]
}

@test "an event with no session id frees nothing, says why, and exits cleanly" {
  mark file-trash session-1 "$now"
  run_hook '{"reason":"other"}'
  [ "$status" -eq 0 ]
  [ "$stderr" = "$(end_no_session_note)" ]
  [ -e "$marks/file-trash" ]
  run_hook 'not json'
  [ "$status" -eq 0 ]
  [ "$stderr" = "$(end_no_session_note)" ]
  [ -e "$marks/file-trash" ]
}

@test "a session id the organizer refuses frees nothing and still exits cleanly" {
  mark file-trash session-1 "$now"
  run_hook '{"session_id":"../session-1"}'
  [ "$status" -eq 0 ]
  [ "$stderr" = "$(refuse_bad_session_note ../session-1)"$'\n'"$(end_not_freed_note ../session-1)" ]
  [ -e "$marks/file-trash" ]
}
