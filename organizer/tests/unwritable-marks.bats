bats_require_minimum_version 1.5.0

# Behavior tests for a marks folder that can be listed but not written: every
# operation that would write it refuses before changing anything, in the
# organizer's own words. Let through, taking and freeing failed with the
# shell's own error, and finishing deleted the brief and rewrote its waiters
# before failing on the mark, leaving a mark that names a brief now gone.

load project

setup() {
  setup_project
  place aidk-plans
  brief file-trash "Trash." "[]" "[aidk-plans]" "[]"
  brief frozen-account "Frozen." "[]" "[aidk-plans]" "[]"
  brief waits "Waits." "[file-trash]" "[aidk-plans]" "[]"
  brief also-waits "Also." "[frozen-account, file-trash]" "[aidk-plans]" "[]"
  mark file-trash session-1 "$now"
  chmod 555 "$marks"
}

# The folders are opened up again whatever a test did, so the run's temporary
# folder can always be cleared.
teardown() {
  [ ! -d "$project/aidk-organizer" ] || chmod u+rwx "$project/aidk-organizer"
  [ ! -d "$marks" ] || chmod u+rwx "$marks"
}

# Every entry of the marks folder, hidden ones too, one per line.
list_marks() {
  ls -A "$marks"
}

@test "taking is refused with the reason, and no mark or draft is left" {
  run --separate-stderr organizer take frozen-account session-2
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_marks_unwritable_note "$marks")" ]
  [ "$(list_marks)" = "file-trash" ]
}

@test "freeing a session is refused with the reason, and its mark stays" {
  run --separate-stderr organizer free session-1
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_marks_unwritable_note "$marks")" ]
  [ -f "$marks/file-trash" ]
}

@test "freeing a brief is refused with the reason, and its mark stays" {
  run --separate-stderr organizer free-brief file-trash
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_marks_unwritable_note "$marks")" ]
  [ -f "$marks/file-trash" ]
}

@test "finishing is refused before the brief or any waiter changes" {
  cp -p "$plans/file-trash.md" "$plans/waits.md" "$plans/also-waits.md" "$BATS_TEST_TMPDIR/"
  run --separate-stderr organizer done file-trash
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_marks_unwritable_note "$marks")" ]
  cmp "$plans/file-trash.md" "$BATS_TEST_TMPDIR/file-trash.md"
  cmp "$plans/waits.md" "$BATS_TEST_TMPDIR/waits.md"
  cmp "$plans/also-waits.md" "$BATS_TEST_TMPDIR/also-waits.md"
  [ "$(ls -A "$plans")" = "$(printf 'also-waits.md\nfile-trash.md\nfrozen-account.md\nwaits.md')" ]
  [ -f "$marks/file-trash" ]
}

# regression: the folder turning read-only between the up-front check and the
# mark's removal must still leave nothing half-finished. An `rm` of the
# suite's own, first on the organizer's path, closes the folder just before it
# removes anything there, which is that moment.
@test "a folder closed after the check still leaves the brief and its waiters as they were" {
  chmod u+rwx "$marks"
  printf '#!/usr/bin/env bash\nfor a in "$@"; do case "$a" in %s/*) chmod 555 %s ;; esac; done\nexec /bin/rm "$@"\n' \
    "$marks" "$marks" >"$fakebin/rm"
  chmod +x "$fakebin/rm"
  cp -p "$plans/file-trash.md" "$plans/waits.md" "$plans/also-waits.md" "$BATS_TEST_TMPDIR/"
  run --separate-stderr organizer done file-trash
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_marks_unwritable_note "$marks")" ]
  cmp "$plans/file-trash.md" "$BATS_TEST_TMPDIR/file-trash.md"
  cmp "$plans/waits.md" "$BATS_TEST_TMPDIR/waits.md"
  cmp "$plans/also-waits.md" "$BATS_TEST_TMPDIR/also-waits.md"
  [ "$(ls -A "$plans")" = "$(printf 'also-waits.md\nfile-trash.md\nfrozen-account.md\nwaits.md')" ]
  [ -f "$marks/file-trash" ]
}

@test "a missing folder is created by taking, and refused in the organizer's words where it cannot be" {
  chmod u+rwx "$marks"
  rm -r "$marks"
  run organizer take frozen-account session-2
  [ "$status" -eq 0 ]
  [ -f "$marks/frozen-account" ]
  rm -r "$marks"
  chmod 555 "$project/aidk-organizer"
  run --separate-stderr organizer take frozen-account session-2
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_marks_unwritable_note "$marks")" ]
  [ ! -e "$marks" ]
}

@test "a missing folder leaves freeing and finishing nothing to remove" {
  chmod u+rwx "$marks"
  rm -r "$marks"
  run organizer free session-1
  [ "$status" -eq 0 ]
  run organizer free-brief file-trash
  [ "$status" -eq 0 ]
  run organizer done file-trash
  [ "$status" -eq 0 ]
  [ ! -e "$plans/file-trash.md" ]
}

@test "the session-end hook says the refusal and lets the session end" {
  run --separate-stderr bash -c "printf '%s' '{\"session_id\":\"session-1\"}' | '$BATS_TEST_DIRNAME/../hooks/end-hook.sh'"
  [ "$status" -eq 0 ]
  [ "$stderr" = "$(refuse_marks_unwritable_note "$marks")"$'\n'"$(end_not_freed_note session-1)" ]
  [ -f "$marks/file-trash" ]
}
