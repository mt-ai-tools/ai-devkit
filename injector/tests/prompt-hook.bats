bats_require_minimum_version 1.5.0

# Behavior tests for the turn-start hook: the digest and the question rule on
# every turn whatever the prompt, the declared collection named, and the turn
# refused whenever the rules did not reach it.

# Every test runs against an empty project of its own unless it says
# otherwise: the hook reads the project's config file, and the project a
# session runs the suite from may well keep one.
setup() {
  hook="$BATS_TEST_DIRNAME/../hooks/prompt-hook.sh"
  . "$BATS_TEST_DIRNAME/../lib/refusal.sh"
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/empty-project"
  mkdir -p "$CLAUDE_PROJECT_DIR"
}

# A private copy of the kit, so a test can break a part of it without touching
# the real one. The rules folder comes along only when asked for; the kit's
# shared readers always do, since the injector reads through them.
copy_kit() {
  kit="$BATS_TEST_TMPDIR/kit"
  mkdir -p "$kit"
  cp -r "$BATS_TEST_DIRNAME/.." "$kit/injector"
  cp -r "$BATS_TEST_DIRNAME/../../lib" "$kit/lib"
  if [ "${1:-}" = "with-rules" ]; then
    mkdir -p "$kit/presets"
    cp -r "$BATS_TEST_DIRNAME/../../presets/rules" "$kit/presets/rules"
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
  mkdir "$CLAUDE_PROJECT_DIR/aidk-conventions"
  printf '# Spacing\n' >"$CLAUDE_PROJECT_DIR/aidk-conventions/spacing.md"
  run bash -c "printf '{}' | '$hook'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Written conventions live in: $CLAUDE_PROJECT_DIR/aidk-conventions"* ]]
}

@test "a conventions folder set in the project's config file is the one named" {
  mkdir -p "$CLAUDE_PROJECT_DIR/docs/conventions"
  printf '# Spacing\n' >"$CLAUDE_PROJECT_DIR/docs/conventions/spacing.md"
  printf 'AIDK_CONVENTIONS=docs/conventions\n' >"$CLAUDE_PROJECT_DIR/aidk-config.env"
  run bash -c "printf '{}' | '$hook'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Written conventions live in: $CLAUDE_PROJECT_DIR/docs/conventions"* ]]
}

@test "a conventions folder set but missing refuses the turn with the config's reason" {
  printf 'AIDK_CONVENTIONS=docs/no-such-folder\n' >"$CLAUDE_PROJECT_DIR/aidk-config.env"
  run --separate-stderr bash -c "printf '{}' | '$hook'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"AIDK_CONVENTIONS is set to $CLAUDE_PROJECT_DIR/docs/no-such-folder"* ]]
  [[ "$stderr" == *"$(turn_refused_note)"* ]]
}

@test "a project without a conventions folder gets no pointer" {
  run bash -c "printf '{}' | '$hook'"
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
  mkdir -p "$kit/presets/rules"
  printf 'not a rule\n' >"$kit/presets/rules/README.md"
  run --separate-stderr bash -c "printf '{}' | '$copied_hook'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$(no_rules_note "$kit/presets/rules")"* ]]
  [[ "$stderr" == *"$(turn_refused_note)"* ]]
}

@test "a step that crashes refuses the turn" {
  copy_kit with-rules
  printf '#!/usr/bin/env bash\nexit 1\n' >"$kit/injector/steps/conventions-pointer.sh"
  run --separate-stderr bash -c "printf '{}' | '$copied_hook'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$(turn_refused_note)"* ]]
}

@test "a shared reader that cannot be loaded refuses the turn" {
  copy_kit with-rules
  rm "$kit/lib/readers/collection.sh"
  run --separate-stderr bash -c "printf '{}' | '$copied_hook'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$(turn_refused_note)"* ]]
}

@test "a missing refusal wording still refuses the turn" {
  copy_kit with-rules
  rm "$kit/injector/lib/refusal.sh"
  run --separate-stderr bash -c "printf '{}' | '$copied_hook'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"Nothing runs until this is fixed."* ]]
}

@test "with no config file the rules are read from the kit's own preset" {
  kit_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  run bash -c "printf '{}' | CLAUDE_PROJECT_DIR='$BATS_TEST_TMPDIR' '$hook'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Full text: $kit_root/presets/rules"* ]]
  [[ "$output" == *"- design-for-growth — "* ]]
}

@test "a rules folder set in the project's config file is the one read" {
  project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project/own-rules"
  printf -- '---\nenforce: [premise]\nsummary: The project'"'"'s own premise.\n---\n# Own\n' >"$project/own-rules/own-premise.md"
  printf 'AIDK_RULES=own-rules\n' >"$project/aidk-config.env"
  run bash -c "printf '{}' | CLAUDE_PROJECT_DIR='$project' '$hook'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Full text: $project/own-rules"* ]]
  [[ "$output" == *"- own-premise — The project's own premise."* ]]
  [[ "$output" != *"design-for-growth"* ]]
}

@test "a config file the kit refuses refuses the turn with the config's own reason" {
  . "$BATS_TEST_DIRNAME/../../lib/readers/config.sh"
  project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf 'AIDK_RULES=no-such-folder\n' >"$project/aidk-config.env"
  run --separate-stderr bash -c "printf '{}' | CLAUDE_PROJECT_DIR='$project' '$hook'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$(config_path_missing_note 1 AIDK_RULES "$project/no-such-folder")"* ]]
  [[ "$stderr" == *"$(turn_refused_note)"* ]]
  [[ "$stderr" != *"$(no_rules_note "")"* ]]
}
