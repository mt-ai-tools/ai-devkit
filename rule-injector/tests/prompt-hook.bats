# Behavior tests for the turn-start hook: the digest and the question rule on
# every turn whatever the prompt, and the declared collection named.

setup() {
  hook="$BATS_TEST_DIRNAME/../hooks/prompt-hook.sh"
}

@test "the digest and the question rule print whatever the prompt reads as" {
  run bash -c "printf '{\"prompt\":\"add the sidebar\"}' | '$hook'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Rules in force"* ]]
  [[ "$output" == *"If this prompt is a question"* ]]
  [[ "$output" == *"- answer-dont-implement — "* ]]
}

@test "the project's conventions folder is named when it holds entries" {
  mkdir "$BATS_TEST_TMPDIR/conventions"
  printf '# Spacing\n' >"$BATS_TEST_TMPDIR/conventions/spacing.md"
  run bash -c "printf '{}' | CLAUDE_PROJECT_DIR='$BATS_TEST_TMPDIR' '$hook'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$BATS_TEST_TMPDIR/conventions"* ]]
}

@test "a project without a conventions folder gets no pointer" {
  run bash -c "printf '{}' | CLAUDE_PROJECT_DIR='$BATS_TEST_TMPDIR' '$hook'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Written conventions live in"* ]]
}
