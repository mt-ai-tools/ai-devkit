bats_require_minimum_version 1.5.0

# Behavior tests for the turn-start hook: the digest and the question rule on
# every turn whatever the prompt, the declared collection named, and the turn
# refused whenever the rules did not reach it.

setup() {
  hook="$BATS_TEST_DIRNAME/../hooks/prompt-hook.sh"
  . "$BATS_TEST_DIRNAME/../lib/refusal.sh"
}

# A private copy of the kit, so a test can break a part of it without touching
# the real one. The rules folder comes along only when asked for.
copy_kit() {
  kit="$BATS_TEST_TMPDIR/kit"
  mkdir -p "$kit"
  cp -r "$BATS_TEST_DIRNAME/.." "$kit/injector"
  if [ "${1:-}" = "with-rules" ]; then
    cp -r "$BATS_TEST_DIRNAME/../../rules" "$kit/rules"
  fi
  copied_hook="$kit/injector/hooks/prompt-hook.sh"
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

@test "a missing rules folder refuses the turn" {
  copy_kit
  run --separate-stderr bash -c "printf '{}' | '$copied_hook'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$(no_rules_note "")"* ]]
  [[ "$stderr" == *"$(turn_refused_note)"* ]]
}

@test "a rules folder holding no rule files refuses the turn" {
  copy_kit
  mkdir "$kit/rules"
  printf 'not a rule\n' >"$kit/rules/README.md"
  run --separate-stderr bash -c "printf '{}' | '$copied_hook'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$(no_rules_note "$kit/rules")"* ]]
  [[ "$stderr" == *"$(turn_refused_note)"* ]]
}

@test "a step that crashes refuses the turn" {
  copy_kit with-rules
  printf '#!/usr/bin/env bash\nexit 1\n' >"$kit/injector/steps/conventions-pointer.sh"
  run --separate-stderr bash -c "printf '{}' | '$copied_hook'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$(turn_refused_note)"* ]]
}
