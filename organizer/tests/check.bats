bats_require_minimum_version 1.5.0

# Behavior tests for the header check: every way a header can be wrong is
# named, one line per problem naming the brief, and a clean folder is silent.

load project

setup() {
  setup_project
  place aidk-plans
  place monoframe
}

@test "a clean folder passes in silence" {
  brief one "One." "[]" "[aidk-plans]" "[monoframe/mf-new]"
  brief two "Two." "[one]" "[monoframe, aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a missing or empty field is named, each on its own line" {
  printf -- '---\nsummary:\nafter: []\n---\n# No lists\n' >"$plans/thin.md"
  printf '# No header at all\n' >"$plans/bare.md"
  run organizer check
  [ "$status" -eq 1 ]
  expected="$(problem_missing_field_note bare summary)
$(problem_missing_field_note bare after)
$(problem_missing_field_note bare touches)
$(problem_missing_field_note bare creates)
$(problem_missing_field_note thin summary)
$(problem_missing_field_note thin touches)
$(problem_missing_field_note thin creates)"
  [ "$output" = "$expected" ]
}

@test "a list not written in brackets is refused, never guessed at" {
  brief loose "Loose." "one, two" "[aidk-plans" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [[ "$output" == *"$(problem_not_a_list_note loose after)"* ]]
  [[ "$output" == *"$(problem_not_a_list_note loose touches)"* ]]
}

@test "a folded summary is refused" {
  brief folded ">" "[]" "[aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_folded_summary_note folded)" ]
}

@test "an after name with no brief behind it is an error, never read as done" {
  brief waits "Waits." "[built-long-ago]" "[aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_after_missing_note waits built-long-ago)" ]
}

@test "an after entry that is no name is refused" {
  brief waits "Waits." "[../escape, Upper]" "[aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_bad_after_name_note waits ../escape)"$'\n'"$(problem_bad_after_name_note waits Upper)" ]
}

@test "every brief on a cycle is reported, and one leading into it is not" {
  brief a "A." "[c]" "[aidk-plans]" "[]"
  brief b "B." "[a]" "[aidk-plans]" "[]"
  brief c "C." "[b]" "[aidk-plans]" "[]"
  brief d "D." "[a]" "[aidk-plans]" "[]"
  brief self "Self." "[self]" "[aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  expected="$(problem_cycle_note a)
$(problem_cycle_note b)
$(problem_cycle_note c)
$(problem_cycle_note self)"
  [ "$output" = "$expected" ]
}

@test "a touches path that does not exist is named" {
  brief edits "Edits." "[]" "[aidk-plans, monoframe/mf-gone]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_touches_missing_note edits monoframe/mf-gone)" ]
}

@test "a creates path may be missing, but its folder may not" {
  brief makes "Makes." "[]" "[]" "[monoframe/mf-new, nowhere/mf-new]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_creates_folder_missing_note makes nowhere/mf-new)" ]
}

@test "an absolute path or one with a .. segment leaves the root and is never looked at" {
  brief out "Out." "[]" "[/etc, aidk-plans/../.., ..]" "[../sibling, a/../b]"
  run organizer check
  [ "$status" -eq 1 ]
  expected="$(problem_path_outside_note out touches /etc)
$(problem_path_outside_note out touches aidk-plans/../..)
$(problem_path_outside_note out touches ..)
$(problem_path_outside_note out creates ../sibling)
$(problem_path_outside_note out creates a/../b)"
  [ "$output" = "$expected" ]
}

@test "a file whose name is no brief name is reported" {
  brief Bad_Name "Bad." "[]" "[aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_bad_name_note Bad_Name)" ]
}

@test "a README in the briefs folder is never a brief" {
  printf '# About the briefs\n' >"$plans/README.md"
  run organizer check
  [ "$status" -eq 0 ]
}

@test "a mark naming a brief that is gone is a problem of the marks" {
  brief here "Here." "[]" "[aidk-plans]" "[]"
  mark gone s1 "$now"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_mark_orphan_note gone)" ]
}
