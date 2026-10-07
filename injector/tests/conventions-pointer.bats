bats_require_minimum_version 1.5.0

# Behavior tests for the conventions pointer: it names a real collection, and
# stays silent on everything that isn't one — unset, missing, or a folder whose
# only file is its own README. A folder it cannot list is refused, not silent.

setup() {
  pointer="$BATS_TEST_DIRNAME/../steps/conventions-pointer.sh"
}

# The folder is opened up again whatever a test did, so the run's temporary
# folder can always be cleared.
teardown() {
  [ ! -d "$BATS_TEST_TMPDIR/conventions" ] || chmod u+rwx "$BATS_TEST_TMPDIR/conventions"
}

@test "a collection with entries is named" {
  mkdir "$BATS_TEST_TMPDIR/conventions"
  printf '# Spacing\n' >"$BATS_TEST_TMPDIR/conventions/spacing.md"
  run "$pointer" "$BATS_TEST_TMPDIR/conventions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$BATS_TEST_TMPDIR/conventions"* ]]
}

@test "the pointer names proposing and asking, not only shaping" {
  mkdir "$BATS_TEST_TMPDIR/conventions"
  printf '# Spacing\n' >"$BATS_TEST_TMPDIR/conventions/spacing.md"
  run "$pointer" "$BATS_TEST_TMPDIR/conventions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"propose it or ask about it"* ]]
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

@test "a folder that cannot be listed fails with the reason, rather than saying nothing" {
  . "$BATS_TEST_DIRNAME/../../lib/readers/collection.sh"
  mkdir "$BATS_TEST_TMPDIR/conventions"
  printf '# Spacing\n' >"$BATS_TEST_TMPDIR/conventions/spacing.md"
  chmod 000 "$BATS_TEST_TMPDIR/conventions"
  run --separate-stderr "$pointer" "$BATS_TEST_TMPDIR/conventions"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [ "$stderr" = "$(collection_unreadable_note "$BATS_TEST_TMPDIR/conventions")" ]
}
