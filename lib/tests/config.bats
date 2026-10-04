bats_require_minimum_version 1.5.0

# Behavior tests for the config reader: no file means the defaults, a setting
# moves one key, every line outside the grammar is refused naming its line, a
# set path must exist while a missing default is only reported, the file is
# never run, and the shipped example stays equal to the defaults.

# The reader is loaded from a private copy of the kit, so `{ai-devkit}` points
# somewhere a test may build folders in without touching the real kit. The
# tests run from a folder that is not the project root, so a path read from
# the working directory instead of the root shows up as a failure.
setup() {
  kit="$BATS_TEST_TMPDIR/kit"
  mkdir -p "$kit/lib"
  cp -r "$BATS_TEST_DIRNAME/../readers" "$kit/lib/readers"
  . "$kit/lib/readers/config.sh"
  kit="$(cd "$kit" && pwd)"
  project="$BATS_TEST_TMPDIR/project"
  mkdir "$project"
  export CLAUDE_PROJECT_DIR="$project"
  mkdir "$BATS_TEST_TMPDIR/elsewhere"
  cd "$BATS_TEST_TMPDIR/elsewhere"
  config="$project/aidk-config.env"
  example="$BATS_TEST_DIRNAME/../../aidk-config.env.example"
  us=$'\037'
}

# The paths every key resolves to with no file, spelled out: these are the
# names an operator creates folders by, so the test pins them rather than
# reading them back from the reader.
default_paths() {
  printf '%s\n' \
    "AIDK_RULES$us$kit/presets/rules" \
    "AIDK_STAND_IN$us$kit/presets/stand-in" \
    "AIDK_CONVENTIONS$us$project/aidk-conventions" \
    "AIDK_PLANS$us$project/aidk-plans" \
    "AIDK_NOTES$us$project/aidk-notes" \
    "AIDK_STAND_IN_HISTORY$us$project/aidk-stand-in" \
    "AIDK_REVIEW$us$project/aidk-review"
}

@test "no file means every key is its default" {
  run list_config_paths
  [ "$status" -eq 0 ]
  [ "$output" = "$(default_paths)" ]
}

# No folder is made first: the example sets nothing until a line is
# uncommented, so a copy made as told never asks for folders to exist.
@test "the example copied unchanged reads the same as no file" {
  cp "$example" "$config"
  run list_config_paths
  [ "$status" -eq 0 ]
  [ "$output" = "$(default_paths)" ]
}

@test "the example's commented settings are the reader's defaults" {
  run sed -n 's/^# \(AIDK_[A-Z0-9_]*=\)/\1/p' "$example"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' "${CONFIG_DEFAULTS[@]}")" ]
}

@test "the example sets nothing until a line is uncommented" {
  run grep -c -E '^[^#[:space:]]' "$example"
  [ "$output" = "0" ]
}

@test "a plain path is read from the project root, the rest keep their defaults" {
  mkdir -p "$project/docs/agent-rules"
  printf 'AIDK_RULES=docs/agent-rules\n' >"$config"
  run list_config_paths
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "AIDK_RULES$us$project/docs/agent-rules" ]
  [ "${lines[2]}" = "AIDK_CONVENTIONS$us$project/aidk-conventions" ]
  [ "${#lines[@]}" -eq 7 ]
}

@test "a path beginning with a slash is taken as written" {
  mkdir "$BATS_TEST_TMPDIR/shared-conventions"
  printf 'AIDK_CONVENTIONS=%s\n' "$BATS_TEST_TMPDIR/shared-conventions" >"$config"
  run get_config_path AIDK_CONVENTIONS
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/shared-conventions" ]
}

@test "the kit token is where the kit sits" {
  mkdir -p "$kit/elsewhere/rules"
  printf 'AIDK_RULES={ai-devkit}/elsewhere/rules\n' >"$config"
  run get_config_path AIDK_RULES
  [ "$status" -eq 0 ]
  [ "$output" = "$kit/elsewhere/rules" ]
}

@test "with no project variable, the working directory is the root" {
  unset CLAUDE_PROJECT_DIR
  cd "$project"
  run get_config_path AIDK_PLANS
  [ "$status" -eq 0 ]
  [ "$output" = "$project/aidk-plans" ]
}

@test "comments and blank lines are skipped, and still counted" {
  mkdir "$project/plans"
  printf '# where the plans are\n\nAIDK_PLANS=plans\n# what follows is wrong\nAIDK_TYPO=x\n' >"$config"
  run --separate-stderr list_config_paths
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(config_unknown_key_note 5 AIDK_TYPO)" ]
  printf '# where the plans are\n\nAIDK_PLANS=plans\n' >"$config"
  run get_config_path AIDK_PLANS
  [ "$status" -eq 0 ]
  [ "$output" = "$project/plans" ]
}

@test "a last line with no line ending is read" {
  mkdir "$project/plans"
  printf 'AIDK_PLANS=plans' >"$config"
  run get_config_path AIDK_PLANS
  [ "$status" -eq 0 ]
  [ "$output" = "$project/plans" ]
}

@test "an unknown key is refused, naming its line" {
  printf '\nAIDK_RULEZ=rules\n' >"$config"
  run --separate-stderr list_config_paths
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(config_unknown_key_note 2 AIDK_RULEZ)" ]
}

@test "an unknown token is refused, naming the token" {
  printf 'AIDK_PLANS={root}/plans\n' >"$config"
  run --separate-stderr list_config_paths
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(config_unknown_token_note 1 AIDK_PLANS '{root}')" ]
  printf 'AIDK_PLANS={ai-devkit/plans\n' >"$config"
  run --separate-stderr list_config_paths
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(config_unknown_token_note 1 AIDK_PLANS '{ai-devkit/plans')" ]
}

@test "a line that is not a setting is refused, naming its line" {
  for line in 'AIDK_PLANS' '=plans' '  # an indented comment'; do
    printf '# first\n%s\n' "$line" >"$config"
    run --separate-stderr list_config_paths
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(config_not_a_setting_note 2)" ]
  done
}

@test "a key outside the grammar is refused, naming it" {
  for key in 'aidk_plans' 'export AIDK_PLANS' 'AIDK_PLANS ' 'AIDK-PLANS'; do
    printf '%s=plans\n' "$key" >"$config"
    run --separate-stderr list_config_paths
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(config_bad_key_note 1 "$key")" ]
  done
}

@test "an empty or padded value is refused" {
  printf 'AIDK_PLANS=\n' >"$config"
  run --separate-stderr list_config_paths
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(config_empty_value_note 1 AIDK_PLANS)" ]
  for value in ' plans' 'plans ' $'plans\r'; do
    printf 'AIDK_PLANS=%s\n' "$value" >"$config"
    run --separate-stderr list_config_paths
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(config_padded_value_note 1 AIDK_PLANS)" ]
  done
}

@test "a value spelled for a shell is refused, and never run" {
  marker="$BATS_TEST_TMPDIR/marker"
  for value in "\$(touch $marker)" "\`touch $marker\`" "\"plans\"" "'plans'" "\$HOME/plans" 'plans\ dir'; do
    printf 'AIDK_PLANS=%s\n' "$value" >"$config"
    run --separate-stderr list_config_paths
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(config_shell_value_note 1 AIDK_PLANS)" ]
  done
  printf '$(touch %s)\n`touch %s`\n' "$marker" "$marker" >"$config"
  run list_config_paths
  [ "$status" -eq 1 ]
  [ ! -e "$marker" ]
}

@test "a key set twice is refused, naming both lines" {
  mkdir "$project/plans" "$project/other-plans"
  printf 'AIDK_PLANS=plans\n\nAIDK_PLANS=other-plans\n' >"$config"
  run --separate-stderr list_config_paths
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(config_key_twice_note 3 AIDK_PLANS 1)" ]
}

@test "a set path that does not exist is refused, naming key and path" {
  printf 'AIDK_CONVENTIONS=convetions\n' >"$config"
  run --separate-stderr list_config_paths
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(config_path_missing_note 1 AIDK_CONVENTIONS "$project/convetions")" ]
}

@test "a default whose folder is missing is reported, not refused" {
  run --separate-stderr get_config_path AIDK_CONVENTIONS
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$project/aidk-conventions" ]
  [ ! -e "$output" ]
}

@test "something at the file's place that is not a file is refused" {
  mkdir "$config"
  run --separate-stderr list_config_paths
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(config_unreadable_note "$config")" ]
}

@test "one key's path is handed back alone" {
  mkdir "$project/plans"
  printf 'AIDK_PLANS=plans\n' >"$config"
  run get_config_path AIDK_PLANS
  [ "$status" -eq 0 ]
  [ "$output" = "$project/plans" ]
}

@test "one key is refused when the file is wrong about another" {
  printf 'AIDK_REVIEW=revew\n' >"$config"
  run --separate-stderr get_config_path AIDK_CONVENTIONS
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(config_path_missing_note 1 AIDK_REVIEW "$project/revew")" ]
}

@test "a key the kit does not read cannot be asked for" {
  run --separate-stderr get_config_path AIDK_NOTHING
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(config_unasked_key_note AIDK_NOTHING)" ]
}

@test "one line parses to its setting, or to nothing for a comment" {
  run parse_config_line 4 'AIDK_PLANS={ai-devkit}/plans'
  [ "$status" -eq 0 ]
  [ "$output" = "AIDK_PLANS$us{ai-devkit}/plans" ]
  run parse_config_line 4 '# a comment'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run --separate-stderr parse_config_line 4 'AIDK_PLANS'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(config_not_a_setting_note 4)" ]
}

@test "the text parses to its settings in order, numbered by line" {
  run parse_config_settings <<<$'# c\nAIDK_NOTES=n\nAIDK_PLANS=p'
  [ "$status" -eq 0 ]
  [ "$output" = "2${us}AIDK_NOTES${us}n"$'\n'"3${us}AIDK_PLANS${us}p" ]
  run --separate-stderr parse_config_settings <<<$'AIDK_NOTES=n\nAIDK_NOTES=m'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(config_key_twice_note 2 AIDK_NOTES 1)" ]
}

@test "a value resolves against the kit and the root" {
  run resolve_config_value '{ai-devkit}/presets/rules' /kit /project
  [ "$output" = "/kit/presets/rules" ]
  run resolve_config_value 'aidk-plans' /kit /project
  [ "$output" = "/project/aidk-plans" ]
  run resolve_config_value '/srv/plans' /kit /project
  [ "$output" = "/srv/plans" ]
}
