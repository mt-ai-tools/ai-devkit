bats_require_minimum_version 1.5.0

# Behavior tests for the marks: taking writes the session and now, a brief
# another session holds is refused, freeing by session frees that session's
# marks only, and freeing by brief frees whoever holds it.

load project

setup() {
  setup_project
  place aidk-plans
  brief file-trash "Trash." "[]" "[aidk-plans]" "[]"
  brief frozen-account "Frozen." "[]" "[aidk-plans]" "[]"
}

@test "taking writes the session and now, making the marks folder" {
  run organizer take file-trash session-1
  [ "$status" -eq 0 ]
  [ "$(cat "$marks/file-trash")" = $'session: session-1\nsince: 2026-10-04T21:30:00Z' ]
}

@test "taking again by the same session leaves the mark as it was" {
  mark file-trash session-1 "2026-10-04T20:00:00Z"
  run organizer take file-trash session-1
  [ "$status" -eq 0 ]
  [ "$(cat "$marks/file-trash")" = $'session: session-1\nsince: 2026-10-04T20:00:00Z' ]
}

@test "a brief another session holds is refused, naming the holder and since" {
  mark file-trash session-1 "2026-10-04T20:00:00Z"
  run --separate-stderr organizer take file-trash session-2
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_taken_note file-trash session-1 2026-10-04T20:00:00Z)" ]
  [ "$(cat "$marks/file-trash")" = $'session: session-1\nsince: 2026-10-04T20:00:00Z' ]
}

@test "a mark that cannot be read refuses the take rather than overwriting it" {
  mkdir -p "$marks"
  printf 'garbage\n' >"$marks/file-trash"
  run --separate-stderr organizer take file-trash session-2
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_mark_unreadable_note file-trash)" ]
  [ "$(cat "$marks/file-trash")" = "garbage" ]
}

@test "a missing brief, a name that is no name, and a bad session are refused" {
  run --separate-stderr organizer take no-such-brief session-1
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_no_brief_note no-such-brief)" ]
  run --separate-stderr organizer take ../file-trash session-1
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_name_note ../file-trash)" ]
  run --separate-stderr organizer take file-trash "../../etc"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_session_note ../../etc)" ]
  run --separate-stderr organizer take file-trash $'s1\nsince: 2000-01-01T00:00:00Z'
  [ "$status" -eq 1 ]
  [ ! -e "$marks/file-trash" ]
}

@test "freeing a session removes its marks and only its marks" {
  mark file-trash session-1 "$now"
  mark frozen-account session-2 "$now"
  mark gone session-1 "$now"
  run organizer free session-1
  [ "$status" -eq 0 ]
  [ ! -e "$marks/file-trash" ]
  [ ! -e "$marks/gone" ]
  [ -e "$marks/frozen-account" ]
}

@test "freeing a session that holds nothing, or with no marks folder, succeeds" {
  run organizer free session-9
  [ "$status" -eq 0 ]
  mark file-trash session-1 "$now"
  run organizer free session-9
  [ "$status" -eq 0 ]
  [ -e "$marks/file-trash" ]
}

@test "freeing a session id that is no id is refused" {
  mark file-trash session-1 "$now"
  run --separate-stderr organizer free "session 1"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_session_note "session 1")" ]
  [ -e "$marks/file-trash" ]
}

@test "freeing a brief removes its mark whoever holds it, even once the brief is gone" {
  mark file-trash session-1 "$now"
  mark gone session-2 "$now"
  run organizer free-brief file-trash
  [ "$status" -eq 0 ]
  [ ! -e "$marks/file-trash" ]
  run organizer free-brief gone
  [ "$status" -eq 0 ]
  [ ! -e "$marks/gone" ]
}

@test "freeing a brief by a name that is no name touches nothing outside the marks" {
  printf 'keep\n' >"$project/aidk-organizer-keep"
  mkdir -p "$marks"
  run --separate-stderr organizer free-brief ../../aidk-organizer-keep
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_name_note ../../aidk-organizer-keep)" ]
  [ -e "$project/aidk-organizer-keep" ]
}

@test "held lists a session's briefs with their ages, and nothing for one holding none" {
  mark file-trash session-1 "2026-10-04T19:30:00Z"
  mark frozen-account session-2 "2026-10-04T21:00:00Z"
  run organizer held session-1
  [ "$status" -eq 0 ]
  [ "$output" = "file-trash"$'\t'"$(age_hours_words 2)" ]
  run organizer held session-9
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "held refuses where a mark might be the session's and cannot be read" {
  mark file-trash session-1 "not a stamp"
  run --separate-stderr organizer held session-1
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_held_unreadable_note file-trash)" ]
  run organizer held session-2
  [ "$status" -eq 0 ]
  printf 'garbage\n' >"$marks/file-trash"
  run --separate-stderr organizer held session-2
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_held_unreadable_note file-trash)" ]
  run --separate-stderr organizer held "session 1"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_session_note "session 1")" ]
}

@test "a half-written mark beside the others is never read as one" {
  mkdir -p "$marks"
  printf 'session: s1\n' >"$marks/.file-trash.123"
  run organizer check
  [ "$status" -eq 0 ]
  run organizer take file-trash session-2
  [ "$status" -eq 0 ]
}

# regression: a link that failed with no mark in its place returned a refusal
# with no words at all. An `ln` of the suite's own, first on the organizer's
# path, fails as a link refused for any reason but a mark already there would.
@test "a mark that cannot be linked into place is refused in words, leaving no draft" {
  printf '#!/usr/bin/env bash\nexit 1\n' >"$fakebin/ln"
  chmod +x "$fakebin/ln"
  run --separate-stderr organizer take file-trash session-1
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_mark_not_placed_note file-trash)" ]
  [ -z "$(ls -A "$marks")" ]
}
