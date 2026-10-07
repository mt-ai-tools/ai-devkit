bats_require_minimum_version 1.5.0

# Behavior tests for the reminder hook: a session owing the exam, with the
# stand-in off, is reminded at the start of every turn, with the exam's
# command and the files it edited; with the stand-in on, or owing nothing,
# the turn starts untouched; and where whether an exam is owed cannot be
# told, the operator and the agent are both told why.

load fake-claude

setup() {
  setup_fake_claude
  hook="$BATS_TEST_DIRNAME/../hooks/reminder-hook.sh"
  . "$lib/words.sh"
  history="$project/aidk-stand-in"
  owed="$history/owed/session-1"
  mkdir -p "$history/owed"
  printf '%s\n' '{"files":["/kit/prompts/sorter.md","/kit/lib/jobs.sh"],"noted":"2026-10-07T10:00:00.000000000Z"}' >"$owed"
  exam_command="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/stand-in.sh exam"
}

teardown() {
  [ ! -d "$history" ] || chmod -R u+rwx "$history"
}

turn_event() {
  jq -cn --arg session "$1" '{session_id: $session, hook_event_name: "UserPromptSubmit", prompt: "Go on."}'
}

run_hook() {
  run --separate-stderr "$hook" <<<"$(turn_event "$1")"
}

@test "a session owing the exam, the stand-in off, is reminded each turn with the command and the files" {
  for turn in 1 2; do
    run_hook session-1
    [ "$status" -eq 0 ]
    [ "$output" = "$(exam_reminder_note "$exam_command" "$(owed_file_line /kit/prompts/sorter.md)"$'\n'"$(owed_file_line /kit/lib/jobs.sh)")" ]
    [[ "$output" == "From the stand-in: "* ]]
  done
}

@test "a session the stand-in is on for, or one owing nothing, starts its turn untouched" {
  mkdir -p "$history/on"
  : >"$history/on/session-1"
  run_hook session-1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run_hook session-2
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "where whether an exam is owed cannot be told, the operator and the agent are told why, and the turn goes on" {
  printf 'not json\n' >"$owed"
  run_hook session-1
  [ "$status" -eq 0 ]
  note="$(exam_reminder_unread_note "$(refuse_owed_unreadable_note "$owed")")"
  [ "$(jq -r .systemMessage <<<"$output")" = "$note" ]
  [ "$(jq -r .hookSpecificOutput.additionalContext <<<"$output")" = "$note" ]
  run --separate-stderr "$hook" <<<'{"session_id":"../escape","prompt":"Go on."}'
  [ "$(jq -r .systemMessage <<<"$output")" = "$(exam_reminder_unread_note "$(refuse_prompt_session_note)")" ]
}
