bats_require_minimum_version 1.5.0

# Behavior tests for the collection reader: every entry file is listed and a
# README never is, a directory that is missing or unset holds no entries, and
# one that is there but cannot be listed is refused, never read as empty.

setup() {
  . "$BATS_TEST_DIRNAME/../readers/collection.sh"
  dir="$BATS_TEST_TMPDIR/collection"
  mkdir "$dir"
}

# The folder is opened up again whatever a test did, so the run's temporary
# folder can always be cleared.
teardown() {
  chmod u+rwx "$dir"
}

@test "every entry is listed, and the README is not" {
  printf '# One\n' >"$dir/one.md"
  printf '# Two\n' >"$dir/two.md"
  printf 'about the folder\n' >"$dir/README.md"
  run list_collection_entries "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "$dir/one.md"$'\n'"$dir/two.md" ]
}

@test "a missing directory lists nothing" {
  run list_collection_entries "$BATS_TEST_TMPDIR/nowhere"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a directory with an entry has entries" {
  printf '# One\n' >"$dir/one.md"
  run collection_has_entries "$dir"
  [ "$status" -eq 0 ]
}

@test "a README alone, a missing directory and an unset path have no entries" {
  printf 'about the folder\n' >"$dir/README.md"
  run collection_has_entries "$dir"
  [ "$status" -eq 1 ]
  run collection_has_entries "$BATS_TEST_TMPDIR/nowhere"
  [ "$status" -eq 1 ]
  run collection_has_entries ""
  [ "$status" -eq 1 ]
}

@test "a folder that cannot be listed is refused with the reason, never read as empty" {
  printf '# One\n' >"$dir/one.md"
  chmod 000 "$dir"
  run --separate-stderr list_collection_entries "$dir"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [ "$stderr" = "$(collection_unreadable_note "$dir")" ]
  run --separate-stderr collection_has_entries "$dir"
  [ "$status" -eq 2 ]
  [ "$stderr" = "$(collection_unreadable_note "$dir")" ]
}

@test "a file where the folder should be is refused too" {
  printf 'not a folder\n' >"$BATS_TEST_TMPDIR/file"
  run --separate-stderr list_collection_entries "$BATS_TEST_TMPDIR/file"
  [ "$status" -ne 0 ]
  [ "$stderr" = "$(collection_unreadable_note "$BATS_TEST_TMPDIR/file")" ]
}
