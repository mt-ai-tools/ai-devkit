bats_require_minimum_version 1.5.0

# Behavior tests for a brief's wait: written into its after list with every
# other byte kept and the path printed, read back one a line, ended by
# finishing the brief waited for; refused, changing nothing, for a brief that
# is unknown, itself, or one that waits back; and read back never as over
# where a name in the list is no brief.

load project

setup() {
  setup_project
  place aidk-plans
  brief file-trash "Trash." "[]" "[aidk-plans]" "[]"
  brief media-bucket "Bucket." "[]" "[aidk-plans]" "[]"
  brief one-reporter "Reporter." "[media-bucket]" "[aidk-plans]" "[]"
}

@test "wait writes the brief waited on into the after list, prints the path, and waits reads it back" {
  run --separate-stderr organizer wait file-trash media-bucket
  [ "$status" -eq 0 ]
  [ "$output" = "$plans/file-trash.md" ]
  [ "$(cat "$plans/file-trash.md")" = "$(printf -- '---\nsummary: Trash.\nafter: [media-bucket]\ntouches: [aidk-plans]\ncreates: []\n---\n\n# file-trash\n\nBody.')" ]
  run organizer wait file-trash one-reporter
  [ "$status" -eq 0 ]
  grep -qxF -- "after: [media-bucket, one-reporter]" "$plans/file-trash.md"
  run --separate-stderr organizer waits file-trash
  [ "$status" -eq 0 ]
  [ "$output" = $'media-bucket\none-reporter' ]
  run organizer list
  [[ "$output" == *"$(list_waiting_line file-trash "media-bucket, one-reporter")"* ]]
}

@test "a wait already written changes nothing and prints nothing" {
  run organizer wait one-reporter media-bucket
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -qxF -- "after: [media-bucket]" "$plans/one-reporter.md"
}

@test "a brief waiting on nothing reads back as nothing" {
  run --separate-stderr organizer waits file-trash
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "finishing the brief waited for ends the wait: waits reads nothing" {
  run organizer wait file-trash media-bucket
  run organizer done media-bucket
  [ "$status" -eq 0 ]
  run organizer waits file-trash
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a taken brief may be written a wait: it stays taken" {
  mark file-trash session-1 "$now"
  run organizer wait file-trash media-bucket
  [ "$status" -eq 0 ]
  run organizer list
  [[ "$output" == *"$(list_taken_line file-trash "0 min" session-)"* ]]
}

@test "an unknown brief, a name that is no name, a brief waiting on itself, or one waiting back is refused, and nothing changes" {
  cp -r "$plans" "$BATS_TEST_TMPDIR/plans-before"
  run --separate-stderr organizer wait file-trash no-such-brief
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_no_brief_note no-such-brief)" ]
  run --separate-stderr organizer wait ../x media-bucket
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_name_note ../x)" ]
  run --separate-stderr organizer wait file-trash file-trash
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_wait_self_note file-trash)" ]
  run --separate-stderr organizer wait media-bucket one-reporter
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_wait_cycle_note media-bucket one-reporter)" ]
  diff -r "$plans" "$BATS_TEST_TMPDIR/plans-before"
}

@test "a wait closing a longer cycle is refused too" {
  brief far-end "Far." "[one-reporter]" "[aidk-plans]" "[]"
  run --separate-stderr organizer wait media-bucket far-end
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_wait_cycle_note media-bucket far-end)" ]
}

@test "an after list that cannot be read, or a folder that cannot be written, is refused, and nothing changes" {
  printf -- '---\nsummary: Broken.\nafter: media-bucket\ntouches: [aidk-plans]\ncreates: []\n---\n' >"$plans/broken.md"
  run --separate-stderr organizer wait broken file-trash
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_header_unreadable_note broken)" ]
  run --separate-stderr organizer waits broken
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_header_unreadable_note broken)" ]
  cp "$plans/file-trash.md" "$BATS_TEST_TMPDIR/file-trash-before"
  chmod a-w "$plans"
  run --separate-stderr organizer wait file-trash media-bucket
  chmod u+w "$plans"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_wait_unwritten_note file-trash)" ]
  cmp "$plans/file-trash.md" "$BATS_TEST_TMPDIR/file-trash-before"
  [ -z "$(find "$plans" -name '.*' -type f)" ]
}

@test "waits never reads a name that is no brief as over: it is refused" {
  brief stranded "Stranded." "[gone-brief]" "[aidk-plans]" "[]"
  run --separate-stderr organizer waits stranded
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_awaited_missing_note stranded gone-brief)" ]
  run --separate-stderr organizer waits no-such-brief
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_no_brief_note no-such-brief)" ]
}
