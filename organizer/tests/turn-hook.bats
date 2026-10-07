bats_require_minimum_version 1.5.0

# Behavior tests for the turn reminder: one line per brief the session holds,
# with its age; nothing for a session holding none; and, where the marks
# cannot be read, the could-not-tell line with the turn let through.

load project

setup() {
  setup_project
  hook="$BATS_TEST_DIRNAME/../hooks/turn-hook.sh"
  place aidk-plans
  brief file-trash "Trash." "[]" "[aidk-plans]" "[]"
  brief frozen-account "Frozen." "[]" "[aidk-plans]" "[]"
}

# The folder is opened up again whatever a test did to it, so the run's
# temporary folder can always be cleared.
teardown() {
  [ ! -d "$marks" ] || chmod u+rwx "$marks"
}

# A turn's event, as Claude Code hands it to a prompt hook. The prompt names a
# brief the session does not hold, so a hook reading it would show.
turn_event() {
  printf '{"session_id":"%s","prompt":"work on frozen-account"}' "$1"
}

# The hook, run on an event, with the organizer's clock pinned.
run_hook() {
  run --separate-stderr bash -c "printf '%s' '$1' | PATH='$fakebin:$PATH' '$hook'"
}

@test "a session holding a brief is told which, how long ago, and how to finish it once nothing is left around it" {
  mark file-trash session-1 "2026-10-04T19:30:00Z"
  mark frozen-account session-2 "2026-10-04T21:00:00Z"
  run_hook "$(turn_event session-1)"
  [ "$status" -eq 0 ]
  [ "$output" = "$(turn_held_note file-trash "$(age_hours_words 2)")" ]
}

@test "a session holding two briefs gets one line for each" {
  mark file-trash session-1 "2026-10-04T19:30:00Z"
  mark frozen-account session-1 "2026-10-04T21:00:00Z"
  run_hook "$(turn_event session-1)"
  [ "$status" -eq 0 ]
  [ "$output" = "$(turn_held_note file-trash "$(age_hours_words 2)")"$'\n'"$(turn_held_note frozen-account "$(age_minutes_words 30)")" ]
}

@test "a session holding none gets nothing" {
  mark file-trash session-2 "2026-10-04T19:30:00Z"
  run_hook "$(turn_event session-1)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -r "$marks"
  run_hook "$(turn_event session-1)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a marks folder that cannot be read gets the could-not-tell line, and the turn goes on" {
  mark file-trash session-1 "2026-10-04T19:30:00Z"
  chmod 000 "$marks"
  run_hook "$(turn_event session-1)"
  [ "$status" -eq 0 ]
  [ "$output" = "$(turn_unknown_note)" ]
}

@test "a mark whose holder cannot be read gets the could-not-tell line" {
  mkdir -p "$marks"
  printf 'garbage\n' >"$marks/file-trash"
  run_hook "$(turn_event session-1)"
  [ "$status" -eq 0 ]
  [ "$output" = "$(turn_unknown_note)" ]
}

@test "an event with no session id gets the could-not-tell line" {
  mark file-trash session-1 "2026-10-04T19:30:00Z"
  run_hook '{"prompt":"work on file-trash"}'
  [ "$status" -eq 0 ]
  [ "$output" = "$(turn_unknown_note)" ]
  run_hook 'not json'
  [ "$status" -eq 0 ]
  [ "$output" = "$(turn_unknown_note)" ]
}
