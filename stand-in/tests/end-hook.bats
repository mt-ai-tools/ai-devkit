bats_require_minimum_version 1.5.0

# Behavior tests for the session-end hook: the ending session's switch,
# record, wait's mark and exam owed are removed and every other session's stay; an event with no session
# id it can use removes nothing, and a switch or a record that cannot be
# removed is said, the other still removed, and the session ends.

load fake-claude

setup() {
  setup_fake_claude
  hook="$BATS_TEST_DIRNAME/../hooks/end-hook.sh"
  . "$lib/words.sh"
  history="$project/aidk-stand-in"
  mkdir -p "$history/on"
  : >"$history/on/session-1"
  : >"$history/on/session-2"
  mkdir -p "$history/sessions"
  printf '{}\n' >"$history/sessions/session-1.json"
  printf '{}\n' >"$history/sessions/session-2.json"
  mkdir -p "$history/woken"
  printf '{}\n' >"$history/woken/session-1"
  printf '{}\n' >"$history/woken/session-2"
  mkdir -p "$history/owed"
  printf '{}\n' >"$history/owed/session-1"
  printf '{}\n' >"$history/owed/session-2"
}

teardown() {
  chmod -R u+rwx "$history"
}

run_hook() {
  run --separate-stderr "$hook" <<<"$1"
}

@test "the ending session's switch, record, wait's mark and exam owed are removed, and only its own" {
  run_hook '{"session_id":"session-1","hook_event_name":"SessionEnd","reason":"prompt_input_exit"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
  [ ! -e "$history/on/session-1" ]
  [ ! -e "$history/sessions/session-1.json" ]
  [ ! -e "$history/woken/session-1" ]
  [ -f "$history/on/session-2" ]
  [ -f "$history/sessions/session-2.json" ]
  [ -f "$history/woken/session-2" ]
  [ ! -e "$history/owed/session-1" ]
  [ -f "$history/owed/session-2" ]
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
  [ -f "$history/sessions/session-1.json" ]
}

@test "a switch that cannot be removed is said, the record still goes, and the session ends cleanly" {
  chmod a-w "$history/on"
  run_hook '{"session_id":"session-1"}'
  [ "$status" -eq 0 ]
  [ "$stderr" = "$(refuse_switch_unremovable_note "$history/on/session-1")"$'\n'"$(end_not_removed_note session-1)" ]
  [ -f "$history/on/session-1" ]
  [ ! -e "$history/sessions/session-1.json" ]
}

@test "a record that cannot be removed is said, the switch still goes, and the session ends cleanly" {
  chmod a-w "$history/sessions"
  run_hook '{"session_id":"session-1"}'
  [ "$status" -eq 0 ]
  [ "$stderr" = "$(refuse_state_unremovable_note "$history/sessions/session-1.json")"$'\n'"$(end_not_removed_note session-1)" ]
  [ ! -e "$history/on/session-1" ]
  [ -f "$history/sessions/session-1.json" ]
}

@test "a wait's mark that cannot be removed is said, the switch and the record still go, and the session ends cleanly" {
  . "$lib/woken.sh"
  chmod a-w "$history/woken"
  run_hook '{"session_id":"session-1"}'
  [ "$status" -eq 0 ]
  [ "$stderr" = "$(refuse_woken_unremovable_note "$history/woken/session-1")"$'\n'"$(end_not_removed_note session-1)" ]
  [ ! -e "$history/on/session-1" ]
  [ ! -e "$history/sessions/session-1.json" ]
  [ -f "$history/woken/session-1" ]
}

@test "an exam owed that cannot be removed is said, the rest still go, and the session ends cleanly" {
  . "$lib/owed.sh"
  chmod a-w "$history/owed"
  run_hook '{"session_id":"session-1"}'
  [ "$status" -eq 0 ]
  [ "$stderr" = "$(refuse_owed_unremovable_note "$history/owed/session-1")"$'\n'"$(end_not_removed_note session-1)" ]
  [ ! -e "$history/on/session-1" ]
  [ ! -e "$history/woken/session-1" ]
  [ -f "$history/owed/session-1" ]
}
