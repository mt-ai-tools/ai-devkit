bats_require_minimum_version 1.5.0

# Behavior tests for a marks folder that exists but cannot be read: every
# operation fails closed. Read as empty, it would offer taken briefs as ready
# and let a held brief be taken, so the list shows the problem and offers
# nothing as ready, the check reports it, and every other operation refuses.

load project

setup() {
  setup_project
  place aidk-plans
  brief file-trash "Trash." "[]" "[aidk-plans]" "[]"
  brief frozen-account "Frozen." "[]" "[aidk-plans]" "[]"
  brief waits "Waits." "[file-trash]" "[aidk-plans]" "[]"
  mark file-trash session-1 "$now"
  chmod 000 "$marks"
}

# The folder is opened up again whatever a test did, so the run's temporary
# folder can always be cleared.
teardown() {
  [ ! -d "$marks" ] || chmod u+rwx "$marks"
}

@test "the list shows the problem first and offers no brief as ready" {
  run organizer list
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "$(list_problems_heading)" ]
  [[ "$output" == *"$(list_problem_line "$(problem_marks_unreadable_note "$marks")")"* ]]
  [[ "$output" != *"$(list_ready_heading)"* ]]
  [[ "$output" == *"$(list_waiting_line waits file-trash)"* ]]
}

@test "the check reports the folder as a problem" {
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_marks_unreadable_note "$marks")" ]
}

@test "taking is refused with the reason" {
  run --separate-stderr organizer take frozen-account session-2
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_marks_unreadable_note "$marks")" ]
}

@test "freeing a session is refused with the reason" {
  run --separate-stderr organizer free session-1
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_marks_unreadable_note "$marks")" ]
}

@test "freeing a brief is refused with the reason" {
  run --separate-stderr organizer free-brief file-trash
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_marks_unreadable_note "$marks")" ]
}

@test "held is refused with the reason" {
  run --separate-stderr organizer held session-1
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_marks_unreadable_note "$marks")" ]
}

@test "finishing is refused before anything changes" {
  run --separate-stderr organizer done file-trash
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_marks_unreadable_note "$marks")" ]
  [ -f "$plans/file-trash.md" ]
  grep -qx 'after: \[file-trash\]' "$plans/waits.md"
}

@test "a missing marks folder is still no marks at all" {
  chmod u+rwx "$marks"
  rm -r "$marks"
  run organizer list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(list_ready_line file-trash Trash.)"* ]]
  run organizer held session-1
  [ "$status" -eq 0 ]
  run organizer free session-1
  [ "$status" -eq 0 ]
}

@test "the taken briefs are refused with the reason" {
  run --separate-stderr organizer taken aidk-plans
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_marks_unreadable_note "$marks")" ]
}
