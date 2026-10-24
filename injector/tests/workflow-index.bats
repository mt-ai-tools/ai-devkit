bats_require_minimum_version 1.5.0

# Behavior tests for the workflow index: one line a file, from the file's own
# description, in name order; a missing folder or a file with no description
# is refused, and nothing is printed.

setup() {
  step="$BATS_TEST_DIRNAME/../steps/workflow-index.sh"
  . "$BATS_TEST_DIRNAME/../lib/refusal.sh"
  workflow="$BATS_TEST_TMPDIR/workflow"
  mkdir "$workflow"
}

described() {
  printf -- '---\ndescription: %s\n---\n\n# Title\n' "$2" >"$workflow/$1"
}

@test "each file is listed by its own description, in name order, with the folder" {
  described s2-route.md "Routing."
  described s1-intake.md "Intake."
  run "$step" "$workflow"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lives in: $workflow"* ]]
  [[ "$output" == *"- s1-intake.md — Intake."$'\n'"- s2-route.md — Routing."* ]]
  [[ "$output" == *"Read the file for the stage you are in before acting." ]]
}

@test "a file that is not markdown is not indexed" {
  described s1-intake.md "Intake."
  printf 'x\n' >"$workflow/notes.txt"
  run "$step" "$workflow"
  [ "$status" -eq 0 ]
  [[ "$output" != *"notes.txt"* ]]
}

@test "a file with no description refuses, naming it, and prints nothing" {
  described s1-intake.md "Intake."
  printf '# No header\n' >"$workflow/s2-route.md"
  run --separate-stderr "$step" "$workflow"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ "$stderr" = "$(workflow_file_undescribed_note "$workflow/s2-route.md")" ]
}

@test "a missing workflow folder refuses, naming it" {
  run --separate-stderr "$step" "$BATS_TEST_TMPDIR/nowhere"
  [ "$status" -eq 2 ]
  [ "$stderr" = "$(no_workflow_note "$BATS_TEST_TMPDIR/nowhere")" ]
}

@test "every file of the kit's own workflow has a description" {
  run "$step" "$BATS_TEST_DIRNAME/../../workflow"
  [ "$status" -eq 0 ]
}
