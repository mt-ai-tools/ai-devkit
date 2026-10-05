bats_require_minimum_version 1.5.0

# Behavior tests for finishing a brief: the brief goes, its name leaves every
# waiter's after list with every other byte kept, its mark is freed, and every
# changed path is printed — or nothing changes at all.

load project

setup() {
  setup_project
  place aidk-plans
  brief media-bucket "Bucket." "[]" "[aidk-plans]" "[]"
  brief one-reporter "Reporter." "[]" "[aidk-plans]" "[]"
  brief file-trash "Trash." "[media-bucket]" "[aidk-plans]" "[]"
  brief users-going "Going." "[one-reporter, media-bucket, mount-parts]" "[aidk-plans]" "[]"
  brief mount-parts "Parts." "[]" "[aidk-plans]" "[]"
}

@test "done deletes the brief, frees its waiters and prints the changed paths" {
  mark media-bucket session-1 "$now"
  run organizer done media-bucket
  [ "$status" -eq 0 ]
  [ "$output" = "$plans/media-bucket.md"$'\n'"$plans/file-trash.md"$'\n'"$plans/users-going.md" ]
  [ ! -e "$plans/media-bucket.md" ]
  [ ! -e "$marks/media-bucket" ]
  run organizer list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(list_ready_line file-trash "Trash.")"* ]]
  [[ "$output" == *"$(list_waiting_line users-going "one-reporter, mount-parts")"* ]]
}

@test "only the after line changes; every other byte stays as it was" {
  printf -- '---\nsummary: Odd.\nafter:   [media-bucket,one-reporter ]\ntouches: [aidk-plans]\ncreates: []\n---\n\nbody  with  spaces\n\tafter: [media-bucket]\nno line ending' >"$plans/odd.md"
  cp "$plans/odd.md" "$BATS_TEST_TMPDIR/odd-before"
  run organizer done media-bucket
  [ "$status" -eq 0 ]
  printf -- '---\nsummary: Odd.\nafter: [one-reporter]\ntouches: [aidk-plans]\ncreates: []\n---\n\nbody  with  spaces\n\tafter: [media-bucket]\nno line ending' >"$BATS_TEST_TMPDIR/odd-expected"
  cmp "$plans/odd.md" "$BATS_TEST_TMPDIR/odd-expected"
  [ "$(cat "$plans/one-reporter.md")" = "$(printf -- '---\nsummary: Reporter.\nafter: []\ntouches: [aidk-plans]\ncreates: []\n---\n\n# one-reporter\n\nBody.')" ]
}

@test "the last name leaving an after list leaves it empty, and the brief ready" {
  run organizer done media-bucket
  [ "$status" -eq 0 ]
  run grep -x 'after: \[\]' "$plans/file-trash.md"
  [ "$status" -eq 0 ]
}

@test "each finish prints only what it changed, and a brief nobody waits on goes alone" {
  run organizer done one-reporter
  [ "$status" -eq 0 ]
  [ "$output" = "$plans/one-reporter.md"$'\n'"$plans/users-going.md" ]
  run organizer done users-going
  [ "$status" -eq 0 ]
  [ "$output" = "$plans/users-going.md" ]
  [ ! -e "$plans/users-going.md" ]
}

@test "a missing brief or a name that is no name is refused, and nothing changes" {
  cp -r "$plans" "$BATS_TEST_TMPDIR/plans-before"
  run --separate-stderr organizer done no-such-brief
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_no_brief_note no-such-brief)" ]
  printf 'keep\n' >"$project/keep.md"
  run --separate-stderr organizer done ../keep
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_name_note ../keep)" ]
  [ -e "$project/keep.md" ]
  diff -r "$plans" "$BATS_TEST_TMPDIR/plans-before"
}

@test "a waiter whose after list cannot be read refuses the finish before any change" {
  printf -- '---\nsummary: Broken.\nafter: media-bucket\ntouches: [aidk-plans]\ncreates: []\n---\n' >"$plans/broken.md"
  cp -r "$plans" "$BATS_TEST_TMPDIR/plans-before"
  run --separate-stderr organizer done media-bucket
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_header_unreadable_note broken)" ]
  diff -r "$plans" "$BATS_TEST_TMPDIR/plans-before"
}
