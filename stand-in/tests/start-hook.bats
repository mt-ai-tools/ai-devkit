bats_require_minimum_version 1.5.0

# Behavior tests for the start hook: with a brief, the brief taken through the
# work organizer, the session switched on and the opener handed over; bare,
# the organizer's list shown and nothing changed; with the session flag, the
# switch and nothing taken; every refusal leaving nothing switched on and
# nothing taken; and every other prompt let go untouched and unsaid. The
# organizer is the kit's own, run on the suite's project.

load fake-claude

setup() {
  setup_fake_claude
  hook="$BATS_TEST_DIRNAME/../hooks/start-hook.sh"
  organizer="$BATS_TEST_DIRNAME/../../organizer/bin/organizer.sh"
  . "$lib/words.sh"
  preset "defaults:Defaults." "workaround"
  opener_file="$preset_dir/challenges/opener.md"
  printf -- '---\nsummary: Opener.\n---\n\n# The opener\n\nRead the brief whole.\n' >"$opener_file"
  history="$project/aidk-stand-in"
  marks="$project/aidk-organizer/taken"
  mkdir -p "$project/aidk-plans"
  brief file-trash "[]"
  brief incidents "[file-trash]"
}

teardown() {
  [ ! -d "$history" ] || chmod -R u+rwx "$history"
}

# A brief in the suite's project, with what it waits on.
brief() {
  printf -- '---\nsummary: The %s brief.\nafter: %s\ntouches: []\ncreates: []\n---\n\n# %s\n' \
    "$1" "$2" "$1" >"$project/aidk-plans/$1.md"
}

# A turn's event, as Claude Code hands it to a prompt hook.
turn_event() {
  jq -cn --arg session "$1" --arg prompt "$2" '{session_id: $session, hook_event_name: "UserPromptSubmit", prompt: $prompt}'
}

run_hook() {
  run --separate-stderr "$hook" <<<"$1"
}

# The briefs a session holds, as the organizer says.
held() {
  "$organizer" held "$1" | cut -f 1
}

@test "with a brief: taken for the session, the session switched on, the opener handed to the model whole" {
  run_hook "$(turn_event session-1 "/devkit-stand-in file-trash")"
  [ "$status" -eq 0 ]
  [ "$(held session-1)" = "file-trash" ]
  [ -f "$history/on/session-1" ]
  [ "$(jq -r '.systemMessage' <<<"$output")" = "$(start_brief_shown_note file-trash)" ]
  [ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$output")" = "UserPromptSubmit" ]
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")" = \
    "$(start_brief_agent_note file-trash "$opener_file" "$(cat "$opener_file")" \
      "$(cd "$BATS_TEST_DIRNAME/../bin" && pwd)/stand-in.sh" wait-brief wait-repository)" ]
  [ "$(jq 'has("decision")' <<<"$output")" = false ]
}

@test "bare: the organizer's list shown whole, nothing taken and nothing switched on" {
  "$organizer" take file-trash session-2
  expected="$("$organizer" list; printf x)"
  expected="${expected%x}"
  run_hook "$(turn_event session-1 "/devkit-stand-in")"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.systemMessage' <<<"$output"; printf x)" = "${expected}"$'\n'x ]
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")" = \
    "$(start_list_agent_note "$(printf '%s' "$expected" | awk 'END { print NR }')")" ]
  [ -z "$(held session-1)" ]
  [ ! -e "$history/on" ]
}

@test "with the session flag: the session switched on, nothing taken" {
  run_hook "$(turn_event session-1 "/devkit-stand-in --session")"
  [ "$status" -eq 0 ]
  [ -f "$history/on/session-1" ]
  [ -z "$(held session-1)" ]
  [ ! -e "$marks" ]
  [ "$(jq -r '.systemMessage' <<<"$output")" = "$(start_session_shown_note)" ]
  [ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")" = "$(start_session_agent_note)" ]
}

@test "a brief another session holds is refused in the organizer's words, and nothing is switched on" {
  "$organizer" take file-trash session-2
  refusal="$("$organizer" take file-trash session-1 2>&1)" || true
  run_hook "$(turn_event session-1 "/devkit-stand-in file-trash")"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ "$(jq -r '.reason' <<<"$output")" = "$(start_refused_note "$refusal")" ]
  [ ! -e "$history/on/session-1" ]
  [ -z "$(held session-1)" ]
  [ "$(held session-2)" = "file-trash" ]
}

@test "a brief the organizer does not know is refused, and nothing is switched on" {
  refusal="$("$organizer" take no-such-brief session-1 2>&1)" || true
  run_hook "$(turn_event session-1 "/devkit-stand-in no-such-brief")"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.reason' <<<"$output")" = "$(start_refused_note "$refusal")" ]
  [ ! -e "$history/on/session-1" ]
  [ ! -e "$marks" ]
}

@test "a session already on keeps its switch when the take is refused" {
  mkdir -p "$history/on"
  : >"$history/on/session-1"
  "$organizer" take file-trash session-2
  run_hook "$(turn_event session-1 "/devkit-stand-in file-trash")"
  [ "$(jq -r '.decision' <<<"$output")" = block ]
  [ -f "$history/on/session-1" ]
}

@test "a switch that cannot be written refuses the start before anything is taken" {
  mkdir -p "$history"
  chmod a-w "$history"
  run_hook "$(turn_event session-1 "/devkit-stand-in file-trash")"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.reason' <<<"$output")" = "$(start_refused_note "$(refuse_switch_unwritable_note "$history/on")")" ]
  [ ! -e "$marks" ]
}

@test "an opener that cannot be read refuses the start before anything is written" {
  rm "$opener_file"
  run_hook "$(turn_event session-1 "/devkit-stand-in file-trash")"
  [ "$(jq -r '.reason' <<<"$output")" = "$(start_refused_note "$(refuse_unreadable_file_note "$opener_file")")" ]
  [ ! -e "$history" ]
  [ ! -e "$marks" ]
}

@test "words the command does not take are refused, and nothing is written" {
  for words in "file-trash incidents" "--sesion"; do
    run_hook "$(turn_event session-1 "/devkit-stand-in $words")"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.reason' <<<"$output")" = "$(start_refused_note "$(refuse_start_usage_note devkit-stand-in --session)")" ]
  done
  [ ! -e "$history" ]
  [ ! -e "$marks" ]
}

@test "the command with an event carrying no session id it can use is refused" {
  run_hook '{"session_id":"../escape","prompt":"/devkit-stand-in file-trash"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.reason' <<<"$output")" = "$(start_refused_note "$(refuse_prompt_session_note)")" ]
  [ ! -e "$history" ]
  [ ! -e "$marks" ]
}

@test "every other prompt passes untouched and unsaid" {
  for prompt in "What's next?" "please run /devkit-stand-in file-trash" "/devkit-stand-in-settled" "/devkit-whats-next"; do
    run_hook "$(turn_event session-1 "$prompt")"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -z "$stderr" ]
  done
  run_hook 'not json'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$history" ]
  [ ! -e "$marks" ]
}
