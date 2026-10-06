bats_require_minimum_version 1.5.0

# Behavior tests for the rules and conventions check: every entry of both
# collections handed over, none invented, and an answer naming anything it
# was not handed refused. Claude Code is the suite's own fake.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/checker.sh"
  rules="$project/rules"
  conventions="$project/conventions"
  mkdir -p "$rules" "$conventions"
  printf '# A\n' >"$rules/a.md"
  printf '# Rules\n' >"$rules/README.md"
  printf '# B\n' >"$conventions/b.md"
  names='["a.md","b.md"]'
}

@test "the entries are every rule, then every convention, and no README" {
  run list_check_entries "$rules" "$conventions"
  [ "$status" -eq 0 ]
  [ "$output" = "[{\"name\":\"a.md\",\"path\":\"$rules/a.md\",\"collection\":\"rules\"},{\"name\":\"b.md\",\"path\":\"$conventions/b.md\",\"collection\":\"conventions\"}]" ]
}

@test "a project with no conventions is checked against its rules alone, and one with no rules is refused" {
  run list_check_entries "$rules" "$project/nowhere"
  [ "$status" -eq 0 ]
  [ "$(jq length <<<"$output")" -eq 1 ]
  run --separate-stderr list_check_entries "$project/nowhere" "$conventions"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_no_rules_note "$project/nowhere")" ]
}

@test "a whole checker's answer passes as it stands" {
  answer='{"breaks":[{"entry":"a.md","why":"It breaks."}],"miscalled":[{"called":"the rule","actually":"a comment"}],"explains_code":false}'
  run refuse_bad_checker_answer "$answer" "$names"
  [ "$status" -eq 0 ]
  [ "$output" = "$answer" ]
}

@test "an item missing a field, holding an extra one, or naming an entry not handed, is refused" {
  run --separate-stderr refuse_bad_checker_answer '{"breaks":[{"entry":"a.md"}],"miscalled":[],"explains_code":false}' "$names"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_break_note)" ]
  run --separate-stderr refuse_bad_checker_answer '{"breaks":[],"miscalled":[{"called":"x","actually":"y","also":"z"}],"explains_code":false}' "$names"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_miscalled_note)" ]
  run --separate-stderr refuse_bad_checker_answer '{"breaks":[{"entry":"c.md","why":"No."}],"miscalled":[],"explains_code":false}' "$names"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unknown_entry_note c.md)" ]
  run --separate-stderr refuse_bad_checker_answer '{"breaks":[],"miscalled":[]}' "$names"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_missing_field_note "$(checker_answer_words)" explains_code)" ]
}

@test "an answer that found nothing sends nothing back" {
  run derive_checker_sendback '{"breaks":[],"miscalled":[],"explains_code":false}' "$(list_check_entries "$rules" "$conventions")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the checker is asked on its own model, and about a question only" {
  export FAKE_ANSWER='{"breaks":[],"miscalled":[],"explains_code":false}'
  entries="$(list_check_entries "$rules" "$conventions")"
  run get_checker_answer "$(whole_form)" "Five or ten? Five." "$entries"
  [ "$status" -eq 0 ]
  grep -qx -- "$CHECKER_MODEL" "$FAKE_ARGS"
  rm "$FAKE_ARGS"
  run --separate-stderr get_checker_answer '{"asks_operator":false,"question":"","options":[],"recommended":"","claims_done":true,"closes_round":false,"guidance_answer":"","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}' "Done." "$entries"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_no_question_note)" ]
  [ ! -e "$FAKE_ARGS" ]
}
