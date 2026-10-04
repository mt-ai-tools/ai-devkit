# Behavior tests for the collection reader: every entry file is listed and a
# README never is, and a directory that is missing or unset holds no entries.

setup() {
  . "$BATS_TEST_DIRNAME/../readers/collection.sh"
  dir="$BATS_TEST_TMPDIR/collection"
  mkdir "$dir"
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
