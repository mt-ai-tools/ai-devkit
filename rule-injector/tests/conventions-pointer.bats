# Behavior tests for the conventions pointer: it names a real collection, and
# stays silent on everything that isn't one — unset, missing, or a folder whose
# only file is its own README.

setup() {
  pointer="$BATS_TEST_DIRNAME/../steps/conventions-pointer.sh"
}

@test "a collection with entries is named" {
  mkdir "$BATS_TEST_TMPDIR/conventions"
  printf '# Spacing\n' >"$BATS_TEST_TMPDIR/conventions/spacing.md"
  run "$pointer" "$BATS_TEST_TMPDIR/conventions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$BATS_TEST_TMPDIR/conventions"* ]]
}

@test "a collection holding only its README says nothing" {
  mkdir "$BATS_TEST_TMPDIR/conventions"
  printf '# conventions\n' >"$BATS_TEST_TMPDIR/conventions/README.md"
  run "$pointer" "$BATS_TEST_TMPDIR/conventions"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a missing directory says nothing" {
  run "$pointer" "$BATS_TEST_TMPDIR/nowhere"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no directory at all says nothing" {
  run "$pointer" ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
