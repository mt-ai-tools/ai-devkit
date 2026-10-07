bats_require_minimum_version 1.5.0

# Behavior tests for a briefs folder that exists but cannot be listed: every
# operation is refused with the reason before it runs. Read as empty, it would
# show nothing to do and let a finish free no waiter. Past the entry, each
# operation refuses it again on its own: a folder that stops being listable
# after the entry looked, here one whose files can still be reached by name,
# never reads as holding no briefs.

load project

setup() {
  setup_project
  place aidk-plans
  brief file-trash "Trash." "[]" "[aidk-plans]" "[]"
  brief waits "Waits." "[file-trash]" "[aidk-plans]" "[]"
  . "$BATS_TEST_DIRNAME/../../lib/readers/collection.sh"
  chmod 000 "$plans"
}

# The folder is opened up again whatever a test did, so the run's temporary
# folder can always be cleared.
teardown() {
  chmod u+rwx "$plans"
}

@test "the list is refused with the reason, and shows nothing as ready" {
  run --separate-stderr organizer list
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(collection_unreadable_note "$plans")" ]
}

@test "taking is refused with the folder's reason, not as an unknown brief" {
  run --separate-stderr organizer take file-trash session-1
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(collection_unreadable_note "$plans")" ]
}

@test "finishing is refused before anything changes" {
  run --separate-stderr organizer done file-trash
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(collection_unreadable_note "$plans")" ]
  chmod u+rwx "$plans"
  [ -f "$plans/file-trash.md" ]
}

@test "the brief rows are refused on their own, never listed as none" {
  . "$BATS_TEST_DIRNAME/../lib/briefs.sh"
  run --separate-stderr list_brief_rows "$plans"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(collection_unreadable_note "$plans")" ]
}

# The organizer's operations, loaded as its entry loads them, for a folder
# whose files can be reached by name but which cannot be listed.
load_operations() {
  local lib="$BATS_TEST_DIRNAME/../lib" part
  for part in words clock briefs marks check list done taken wait; do
    . "$lib/$part.sh"
  done
  chmod u=wx "$plans"
}

@test "past the entry, the list and the check are refused rather than shown empty" {
  load_operations
  run --separate-stderr list_briefs "$plans" "$project" "$marks" "$now"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(collection_unreadable_note "$plans")" ]
  run --separate-stderr list_problem_lines "$plans" "$project" "$marks"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(collection_unreadable_note "$plans")" ]
}

@test "past the entry, finishing is refused and the brief stays" {
  load_operations
  run --separate-stderr finish_brief "$plans" "$marks" file-trash
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(collection_unreadable_note "$plans")" ]
  [ -f "$plans/file-trash.md" ]
}

@test "past the entry, a wait is refused and nothing is written" {
  chmod u+rwx "$plans"
  brief other "Other." "[]" "[aidk-plans]" "[]"
  load_operations
  run --separate-stderr write_wait "$plans" other file-trash
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(collection_unreadable_note "$plans")" ]
  grep -qx 'after: \[\]' "$plans/other.md"
}

@test "past the entry, the taken briefs are refused rather than listed as none" {
  mark file-trash session-1 "$now"
  load_operations
  run --separate-stderr list_taken_briefs "$plans" "$marks"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(collection_unreadable_note "$plans")" ]
}
