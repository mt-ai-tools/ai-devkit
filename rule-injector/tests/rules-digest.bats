# Behavior tests for the digest: tagged summaries appear, untagged ones don't,
# and a rule with broken frontmatter is named instead of silently dropped.

setup() {
  digest="$BATS_TEST_DIRNAME/../steps/rules-digest.sh"
  rules="$BATS_TEST_TMPDIR/rules"
  mkdir "$rules"
  printf -- '---\nenforce: [premise]\nsummary: Premise summary.\n---\n# P\n' >"$rules/premise-rule.md"
  printf -- '---\nenforce: [before-thinking]\nsummary: Thinking summary.\n---\n# T\n' >"$rules/thinking-rule.md"
  printf -- '---\nenforce: [before-finishing]\nsummary: Finishing summary.\n---\n# F\n' >"$rules/finishing-rule.md"
  printf -- '---\nenforce: [before-thinking]\n---\n# Broken: no summary\n' >"$rules/no-summary.md"
  printf -- '# Broken: no frontmatter at all\n' >"$rules/no-frontmatter.md"
  printf 'not a rule\n' >"$rules/README.md"
}

@test "premise and before-thinking rules appear with their summaries" {
  run "$digest" "$rules"
  [ "$status" -eq 0 ]
  [[ "$output" == *"premise-rule — Premise summary."* ]]
  [[ "$output" == *"thinking-rule — Thinking summary."* ]]
}

@test "before-finishing rules and the README stay out of the digest" {
  run "$digest" "$rules"
  [[ "$output" != *"Finishing summary."* ]]
  [[ "$output" != *"not a rule"* ]]
}

@test "a rule missing frontmatter is named rather than dropped" {
  run "$digest" "$rules"
  [[ "$output" == *"no-summary — no summary:"* ]]
  [[ "$output" == *"no-frontmatter — no enforce: and summary:"* ]]
}

@test "a missing rules directory is reported, not passed over" {
  run "$digest" "$BATS_TEST_TMPDIR/nowhere"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No rules loaded"* ]]
}
