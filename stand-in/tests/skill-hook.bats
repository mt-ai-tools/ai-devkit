bats_require_minimum_version 1.5.0

# Behavior tests for the stand-in's skill hook: silent for any other skill;
# the settled list empty with its plain line during the trial; a settled
# question listed by its number, today's by default; one reopened in full,
# with its exchange on request, and handed to the agent; and a number, words
# or a log it cannot use refused plainly.

load fake-claude
load question-log

setup() {
  setup_fake_claude
  hook="$BATS_TEST_DIRNAME/../hooks/skill-hook.sh"
  . "$lib/words.sh"
  . "$lib/question-log.sh"
  . "$lib/ladder.sh"
  history="$project/aidk-stand-in"
  # The day is read in the machine's zone, so the suite names the zone.
  export TZ=UTC
  # A `date` of the suite's own, first on the hook's path only, pins today.
  # Not on the suite's own path: bats times its tests with `date`.
  datebin="$BATS_TEST_TMPDIR/datebin"
  mkdir -p "$datebin"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "2026-10-06"\n' >"$datebin/date"
  chmod +x "$datebin/date"
  answer="$BATS_TEST_TMPDIR/answer.json"
}

# The summary's parts of the log line numbered so, as the suite's log lines
# hold them, spelled in the operator's order, the reading's part given
# standing before the call: the same parts the gate's message showed.
reopened_parts() {
  gate_problem_part "A call fails now and then. ($1)"
  gate_first_recommendation_part "Five tries."
  gate_what_moved_part "Nothing."
  gate_recommends_now_part "Five tries."
  [ -z "${2:-}" ] || gate_reading_note "$2"
  gate_operator_call_part "Five or ten; no risk was named."
}

# A skill-loading event, as Claude Code hands it to an after-tool hook.
skill_event() {
  jq -cn --arg skill "$1" --arg args "${2:-}" '{tool_name: "Skill", tool_input: ({skill: $skill} + (if $args == "" then {} else {args: $args} end))}'
}

# The hook, run on a skill loading; its answer goes to a file so every byte
# of it stays.
run_hook() {
  skill_event "$1" "${2:-}" | PATH="$datebin:$PATH" "$hook" >"$answer"
}

shown() { jq -j '.systemMessage' "$answer"; }
note() { jq -r '.hookSpecificOutput.additionalContext' "$answer"; }

# Three lines: two settled, today and yesterday, and one that reached the
# operator today.
three_lines() {
  add_log_lines "$history" \
    "$(log_line 1 "$OUTCOME_SETTLED" session-1 2026-10-05T09:00:00Z five)" \
    "$(log_line 2 "$OUTCOME_TO_OPERATOR" session-1 2026-10-06T09:00:00Z five)" \
    "$(log_line 3 "$OUTCOME_SETTLED" session-2 2026-10-06T14:05:00Z five '["file-trash"]')"
}

@test "another skill, or another tool, gets no answer" {
  run_hook other-skill
  [ ! -s "$answer" ]
  printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | "$hook" >"$answer"
  [ ! -s "$answer" ]
}

@test "during the trial the settled list says plainly that nothing was settled" {
  run_hook devkit-stand-in-settled
  [ "$(shown)" = "$(settled_empty_note)" ]
  [ "$(note)" = "$(skill_settled_shown_note 1)" ]
  add_log_lines "$history" "$(log_line 1 "$OUTCOME_TO_OPERATOR" session-1 2026-10-06T09:00:00Z)"
  run_hook devkit-stand-in-settled
  [ "$(shown)" = "$(settled_empty_note)" ]
}

@test "today's settled questions are listed by their log numbers, retold, with what, when and where" {
  three_lines
  run_hook devkit-stand-in-settled
  expected="$(settled_today_heading
    settled_item_line 3 "Should a call be tried five or ten times? (3)"
    settled_detail_line five 14:05 "$(settled_where_brief_words session-2 file-trash)"
    settled_reopen_hint)"
  [ "$(shown)" = "$expected" ]
  [ "$(note)" = "$(skill_settled_shown_note 4)" ]
}

@test "every settled question is listed when asked for all, and other words are refused" {
  three_lines
  run_hook devkit-stand-in-settled all
  expected="$(settled_all_heading
    settled_item_line 1 "Should a call be tried five or ten times? (1)"
    settled_detail_line five "2026-10-05 09:00" "$(settled_where_session_words session-1)"
    settled_item_line 3 "Should a call be tried five or ten times? (3)"
    settled_detail_line five "2026-10-06 14:05" "$(settled_where_brief_words session-2 file-trash)"
    settled_reopen_hint)"
  [ "$(shown)" = "$expected" ]
  run_hook devkit-stand-in-settled yesterday
  [ "$(shown)" = "$(settled_usage_note)" ]
  [ "$(note)" = "$(skill_refusal_shown_note)" ]
}

@test "a settled question is reopened in full, and handed to the agent to ask again" {
  three_lines
  run_hook devkit-stand-in-reopen 3
  expected="$(reopen_heading 3 "2026-10-06 14:05" "$(settled_where_brief_words session-2 file-trash)"
    reopen_question_line "Should a call be tried five or ten times? (3)"
    reopen_settled_line five
    reopened_parts 3
    reopen_exchange_hint)"
  [ "$(shown)" = "$expected" ]
  [ "$(note)" = "$(reopen_agent_note 3 "Five retries or ten? (3)" "five${LADDER_OPTION_SEPARATOR}ten" five)" ]
}

@test "a reopened question shows its exchange word for word on request, and its reading where one ran" {
  add_log_lines "$history" "$(jq -c '.reading = "Ten is safer."' <<<"$(log_line 3 "$OUTCOME_SETTLED" session-2 2026-10-06T14:05:00Z)")"
  run_hook devkit-stand-in-reopen "3 exchange"
  expected="$(reopen_heading 3 "2026-10-06 14:05" "$(settled_where_session_words session-2)"
    reopen_question_line "Should a call be tried five or ten times? (3)"
    reopen_settled_line five
    reopened_parts 3 "Ten is safer."
    reopen_exchange_heading
    reopen_agent_turn_heading; printf 'Five or ten? I recommend five. (3)\n'
    reopen_stand_in_turn_heading; printf 'From the stand-in: Sure?\n'
    reopen_agent_turn_heading; printf 'Five.\n')"
  [ "$(shown)" = "$expected" ]
}

@test "a reopened question whose summary failed shows the answers as given, then its reading" {
  add_log_lines "$history" "$(jq -c '.summary = null | .reading = "Ten is safer."' <<<"$(log_line 3 "$OUTCOME_SETTLED" session-2 2026-10-06T14:05:00Z)")"
  run_hook devkit-stand-in-reopen 3
  expected="$(reopen_heading 3 "2026-10-06 14:05" "$(settled_where_session_words session-2)"
    reopen_question_line "Should a call be tried five or ten times? (3)"
    reopen_settled_line five
    gate_answers_heading
    gate_answer_line 1 five "five${LADDER_OPTION_SEPARATOR}ten"
    gate_pick_line 2 five
    gate_pick_line 3 five
    gate_reading_note "Ten is safer."
    reopen_exchange_hint)"
  [ "$(shown)" = "$expected" ]
}

@test "a number no settled question has is refused plainly, one that reached the operator included" {
  three_lines
  for number in 2 9; do
    run_hook devkit-stand-in-reopen "$number"
    [ "$(shown)" = "$(reopen_unknown_note "$number")" ]
    [ "$(note)" = "$(skill_refusal_shown_note)" ]
  done
}

@test "during the trial there is nothing to reopen, and words that are no number are refused first" {
  run_hook devkit-stand-in-reopen 3
  [ "$(shown)" = "$(reopen_nothing_note)" ]
  for words in "" "three" "3 more" "0" "3 exchange now"; do
    run_hook devkit-stand-in-reopen "$words"
    [ "$(shown)" = "$(reopen_usage_note)" ]
  done
}

@test "a log holding a torn line is refused, shown to the user" {
  add_log_lines "$history" '{"number":1,"outc'
  run_hook devkit-stand-in-settled
  [ "$(shown)" = "$(refuse_log_unreadable_note "$history/log/questions.jsonl")" ]
  [ "$(note)" = "$(skill_refusal_shown_note)" ]
}

@test "each skill's name is read from its own file" {
  kit="$BATS_TEST_TMPDIR/kit"
  mkdir -p "$kit"
  cp -r "$BATS_TEST_DIRNAME/../../lib" "$BATS_TEST_DIRNAME/../../stand-in" "$kit/"
  sed -i 's/^name: devkit-stand-in-settled$/name: renamed-settled/' "$kit/stand-in/skills/settled/SKILL.md"
  hook="$kit/stand-in/hooks/skill-hook.sh"
  run_hook devkit-stand-in-settled
  [ ! -s "$answer" ]
  run_hook renamed-settled
  [ "$(shown)" = "$(settled_empty_note)" ]
  sed -i '/^name: /d' "$kit/stand-in/skills/reopen/SKILL.md"
  run --separate-stderr bash -c "$(declare -f skill_event); skill_event renamed-settled | '$hook'"
  [ "$status" -ne 0 ]
  [ "$stderr" = "$(skill_name_unreadable_note "$kit/stand-in/skills/reopen/SKILL.md")" ]
}
