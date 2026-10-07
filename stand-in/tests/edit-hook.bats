bats_require_minimum_version 1.5.0

# Behavior tests for the edit hook: an edit by any of Claude Code's
# file-editing tools of what the stand-in judges by — its preset, its prompts
# or its model list — marks the session's exam owed, with the file, whether
# the stand-in is on for the session or not; any other file, and any other
# tool, is left alone, silently; and where an edit cannot be checked or noted,
# the operator is told no exam is asked for it.

load fake-claude

setup() {
  setup_fake_claude
  hook="$BATS_TEST_DIRNAME/../hooks/edit-hook.sh"
  . "$lib/words.sh"
  preset "naming:Names." "workaround"
  history="$project/aidk-stand-in"
  owed="$history/owed/session-1"
  prompts="$(cd "$BATS_TEST_DIRNAME/../prompts" && pwd)"
  models="$(cd "$BATS_TEST_DIRNAME/../lib" && pwd)/jobs.sh"
}

teardown() {
  [ ! -d "$history" ] || chmod -R u+rwx "$history"
}

# An after-tool event, as Claude Code hands it to the hook, for the session,
# tool and file named. Claude Code's own names for its tools, and the field
# each one's input names its file by, are spelled here, since Claude Code,
# not the stand-in, fixes them.
edit_event() {
  local field=file_path
  [ "$2" != NotebookEdit ] || field=notebook_path
  jq -cn --arg session "$1" --arg tool "$2" --arg field "$field" --arg path "$3" --arg cwd "$project" '{
    session_id: $session, hook_event_name: "PostToolUse", cwd: $cwd, tool_name: $tool,
    tool_input: {($field): $path}, tool_response: {}}'
}

run_hook() {
  run --separate-stderr "$hook" <<<"$1"
}

@test "an edit of the preset, a prompt or the model list marks the session's exam owed, by every editing tool" {
  run_hook "$(edit_event session-1 Edit "$preset_dir/questions/naming.md")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(jq -c .files "$owed")" = "$(jq -cn --arg f "$preset_dir/questions/naming.md" '[$f]')" ]
  run_hook "$(edit_event session-1 Write "$prompts/sorter.md")"
  run_hook "$(edit_event session-1 MultiEdit "$models")"
  run_hook "$(edit_event session-1 NotebookEdit "$preset_dir/challenges/new.ipynb")"
  [ -z "$output" ]
  [ "$(jq -c .files "$owed")" = "$(jq -cn --arg a "$preset_dir/questions/naming.md" --arg b "$prompts/sorter.md" \
    --arg c "$models" --arg d "$preset_dir/challenges/new.ipynb" '[$a, $b, $c, $d] | unique')" ]
}

@test "the same file edited again stays listed once, and the mark is noted anew" {
  run_hook "$(edit_event session-1 Edit "$preset_dir/questions/naming.md")"
  noted="$(jq -r .noted "$owed")"
  run_hook "$(edit_event session-1 Edit "$preset_dir/questions/naming.md")"
  [ "$(jq -c '.files | length' "$owed")" = 1 ]
  [ "$(jq -r .noted "$owed")" != "$noted" ]
}

@test "a path read from the session's folder, or reached through a link or a dot-dot, is found the same" {
  ln -s "$preset_dir" "$project/linked-preset"
  run_hook "$(edit_event session-1 Edit "linked-preset/questions/../challenges/risks.md")"
  [ "$(jq -r '.files[0]' "$owed")" = "$preset_dir/challenges/risks.md" ]
}

@test "an edit of any other file, or another tool, marks nothing and says nothing" {
  run_hook "$(edit_event session-1 Edit "$project/notes.md")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run_hook "$(edit_event session-1 Write "$preset_dir-copy/questions/naming.md")"
  [ -z "$output" ]
  run_hook "$(jq -cn --arg cwd "$project" '{session_id: "session-1", tool_name: "Bash", cwd: $cwd,
    tool_input: {command: "echo x > preset/questions/naming.md"}}')"
  [ -z "$output" ]
  run_hook 'not json'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$history/owed" ]
}

@test "an edit with no session id it can use, or no file, tells the operator no exam is asked for it" {
  run_hook "$(edit_event ../escape Edit "$preset_dir/questions/naming.md")"
  [ "$status" -eq 0 ]
  [ "$(jq -r .systemMessage <<<"$output")" = "$(edit_unnoted_note "$(refuse_edit_session_note)")" ]
  run_hook '{"session_id":"session-1","tool_name":"Edit","tool_input":{}}'
  [ "$(jq -r .systemMessage <<<"$output")" = "$(edit_unnoted_note "$(refuse_edit_path_note)")" ]
  [ ! -e "$history/owed" ]
}

@test "a mark that cannot be written tells the operator no exam is asked for the edit" {
  mkdir -p "$history/owed"
  chmod a-w "$history/owed"
  run_hook "$(edit_event session-1 Edit "$preset_dir/questions/naming.md")"
  [ "$status" -eq 0 ]
  [ "$(jq -r .systemMessage <<<"$output")" = "$(edit_unnoted_note "$(refuse_owed_unwritable_note "$history/owed")")" ]
}
