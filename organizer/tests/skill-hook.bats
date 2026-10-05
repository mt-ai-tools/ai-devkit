bats_require_minimum_version 1.5.0

# Behavior tests for the skill's hook: silent for any other skill; for the
# organizer's own, the list shown byte for byte with a note for the model,
# a failing list shown all the same, and an organizer that cannot run said
# so rather than left silent.

load project

setup() {
  setup_project
  hook="$BATS_TEST_DIRNAME/../hooks/skill-hook.sh"
  place aidk-plans
  answer="$BATS_TEST_TMPDIR/answer.json"
}

# A skill-loading event, as Claude Code hands it to an after-tool hook.
skill_event() {
  printf '{"tool_name":"Skill","tool_input":{"skill":"%s"}}' "$1"
}

# The given hook, run on an event, with the organizer's clock pinned; its
# answer goes to a file so every byte of it stays.
run_hook() {
  skill_event "$2" | PATH="$fakebin:$PATH" "$1" >"$answer"
}

# A private copy of the kit, so a test can break or rename a part of it
# without touching the real one.
copy_kit() {
  kit="$BATS_TEST_TMPDIR/kit"
  mkdir -p "$kit"
  cp -r "$BATS_TEST_DIRNAME/.." "$kit/organizer"
  cp -r "$BATS_TEST_DIRNAME/../../lib" "$kit/lib"
  copied_hook="$kit/organizer/hooks/skill-hook.sh"
}

@test "another skill gets no answer" {
  run bash -c "$(declare -f skill_event); skill_event other-skill | '$hook'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a tool other than Skill gets no answer" {
  run bash -c "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}' | '$hook'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the organizer's skill gets the list byte for byte, with a note for the model" {
  brief file-trash "Deleted files wait before they go." "[]" "[aidk-plans]" "[]"
  run_hook "$hook" devkit-whats-next
  organizer list >"$BATS_TEST_TMPDIR/expected" 2>&1
  jq -j '.systemMessage' "$answer" >"$BATS_TEST_TMPDIR/shown"
  cmp "$BATS_TEST_TMPDIR/shown" "$BATS_TEST_TMPDIR/expected"
  [ "$(jq -r '.hookSpecificOutput.hookEventName' "$answer")" = "PostToolUse" ]
  [ "$(jq -r '.hookSpecificOutput.additionalContext' "$answer")" = "$(skill_list_shown_note 2)" ]
}

@test "a list whose check finds problems is shown all the same" {
  brief waits "Waits." "[no-such-brief]" "[aidk-plans]" "[]"
  run_hook "$hook" devkit-whats-next
  run organizer list
  [ "$status" -eq 1 ]
  organizer list >"$BATS_TEST_TMPDIR/expected" 2>&1 || true
  jq -j '.systemMessage' "$answer" >"$BATS_TEST_TMPDIR/shown"
  cmp "$BATS_TEST_TMPDIR/shown" "$BATS_TEST_TMPDIR/expected"
  grep -qF "$(problem_after_missing_note waits no-such-brief)" "$BATS_TEST_TMPDIR/shown"
}

@test "the skill's name is read from the skill's own file" {
  copy_kit
  sed -i 's/^name: devkit-whats-next$/name: renamed-skill/' "$kit/organizer/skills/whats-next/SKILL.md"
  brief file-trash "Deleted files wait before they go." "[]" "[aidk-plans]" "[]"
  run_hook "$copied_hook" devkit-whats-next
  [ ! -s "$answer" ]
  run_hook "$copied_hook" renamed-skill
  [ "$(jq -r '.hookSpecificOutput.additionalContext' "$answer")" = "$(skill_list_shown_note 2)" ]
}

@test "a missing organizer is said so to the user" {
  copy_kit
  rm "$kit/organizer/bin/organizer.sh"
  run_hook "$copied_hook" devkit-whats-next
  [ "$(jq -r '.systemMessage' "$answer")" = "$(skill_organizer_unrunnable_note "$kit/organizer/bin/organizer.sh")" ]
  [ "$(jq -r '.hookSpecificOutput.additionalContext' "$answer")" = "$(skill_unrunnable_shown_note)" ]
}

@test "an organizer that cannot be executed is said so to the user" {
  copy_kit
  chmod -x "$kit/organizer/bin/organizer.sh"
  run_hook "$copied_hook" devkit-whats-next
  [ "$(jq -r '.systemMessage' "$answer")" = "$(skill_organizer_unrunnable_note "$kit/organizer/bin/organizer.sh")" ]
}

@test "a skill file with no name fails loudly rather than staying silent" {
  copy_kit
  sed -i '/^name: /d' "$kit/organizer/skills/whats-next/SKILL.md"
  run --separate-stderr bash -c "$(declare -f skill_event); skill_event devkit-whats-next | '$copied_hook'"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [ "$stderr" = "$(skill_name_unreadable_note "$kit/organizer/skills/whats-next/SKILL.md")" ]
}
