bats_require_minimum_version 1.5.0

# Behavior tests for the session-end hook: the ending session's switch is
# removed and every other session's stays; an event with no session id it can
# use, or a switch that cannot be removed, removes nothing, says why, and lets
# the session end.

load fake-claude

setup() {
  setup_fake_claude
  hook="$BATS_TEST_DIRNAME/../hooks/end-hook.sh"
  . "$lib/words.sh"
  history="$project/aidk-stand-in"
  mkdir -p "$history/on"
  : >"$history/on/session-1"
  : >"$history/on/session-2"
}

teardown() {
  chmod -R u+rwx "$history"
}

run_hook() {
  run --separate-stderr "$hook" <<<"$1"
}

@test "the ending session's switch is removed, and only its own" {
  run_hook '{"session_id":"session-1","hook_event_name":"SessionEnd","reason":"prompt_input_exit"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$history/on/session-1" ]
  [ -f "$history/on/session-2" ]
}

@test "a session the stand-in was never on for ends cleanly, saying nothing" {
  run_hook '{"session_id":"session-3","reason":"other"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "an event with no session id it can use removes nothing, says why, and exits cleanly" {
  for event in '{"reason":"other"}' 'not json' '{"session_id":"../on/session-1"}'; do
    run_hook "$event"
    [ "$status" -eq 0 ]
    [ "$stderr" = "$(refuse_end_session_note)" ]
  done
  [ -f "$history/on/session-1" ]
}

@test "a switch that cannot be removed is said, and the session still ends cleanly" {
  chmod a-w "$history/on"
  run_hook '{"session_id":"session-1"}'
  [ "$status" -eq 0 ]
  [ "$stderr" = "$(refuse_switch_unremovable_note "$history/on/session-1")"$'\n'"$(end_not_removed_note session-1)" ]
  [ -f "$history/on/session-1" ]
}
