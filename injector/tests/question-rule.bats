# Behavior tests for the question rule: it quotes the rule's own summary, and
# says nothing when that rule is not there to be quoted.

setup() {
  step="$BATS_TEST_DIRNAME/../steps/question-rule.sh"
  rules="$BATS_TEST_TMPDIR/rules"
  mkdir "$rules"
  shapes="$BATS_TEST_TMPDIR/shapes"
  mkdir "$shapes"
}

@test "the rule's own summary is quoted" {
  printf -- '---\nenforce: [before-thinking]\nsummary: A question gets a text answer, not code.\n---\n# Answer\n' >"$rules/answer-dont-implement.md"
  run "$step" "$rules" "$shapes"
  [ "$status" -eq 0 ]
  [[ "$output" == *"If this prompt is a question"* ]]
  [[ "$output" == *"A question gets a text answer, not code."* ]]
}

@test "a collection without the rule says nothing" {
  run "$step" "$rules" "$shapes"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a rule with no summary says nothing" {
  printf '# Answer, do not implement\n' >"$rules/answer-dont-implement.md"
  run "$step" "$rules" "$shapes"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the rule is found in whichever folder holds it" {
  printf -- '---\nenforce: [before-thinking]\nsummary: Found among the shapes.\n---\n# Answer\n' >"$shapes/answer-dont-implement.md"
  run "$step" "$rules" "$shapes"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found among the shapes."* ]]
}
