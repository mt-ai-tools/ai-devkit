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
  brief p2-required one "One." "[]" "[aidk-plans]" "[monoframe/mf-new]"
  brief p2-required two "Two." "[one]" "[monoframe, aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a missing or empty field is named, each on its own line" {
  printf -- '---\nsummary:\nafter: []\n---\n# No lists\n' >"$plans/p2-required/thin.md"
  printf '# No header at all\n' >"$plans/p2-required/bare.md"
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
  brief p2-required loose "Loose." "one, two" "[aidk-plans" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [[ "$output" == *"$(problem_not_a_list_note loose after)"* ]]
  [[ "$output" == *"$(problem_not_a_list_note loose touches)"* ]]
}

@test "a folded summary is refused" {
  brief p2-required folded ">" "[]" "[aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_folded_summary_note folded)" ]
}

@test "an after name with no brief behind it is an error, never read as done" {
  brief p2-required waits "Waits." "[built-long-ago]" "[aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_after_missing_note waits built-long-ago)" ]
}

@test "an after entry that is no name is refused" {
  brief p2-required waits "Waits." "[../escape, Upper]" "[aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_bad_after_name_note waits ../escape)"$'\n'"$(problem_bad_after_name_note waits Upper)" ]
}

@test "every brief on a cycle is reported, and one leading into it is not" {
  brief p2-required a "A." "[c]" "[aidk-plans]" "[]"
  brief p2-required b "B." "[a]" "[aidk-plans]" "[]"
  brief p2-required c "C." "[b]" "[aidk-plans]" "[]"
  brief p2-required d "D." "[a]" "[aidk-plans]" "[]"
  brief p2-required self "Self." "[self]" "[aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  expected="$(problem_cycle_note a)
$(problem_cycle_note b)
$(problem_cycle_note c)
$(problem_cycle_note self)"
  [ "$output" = "$expected" ]
}

@test "a touches path that does not exist is named" {
  brief p2-required edits "Edits." "[]" "[aidk-plans, monoframe/mf-gone]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_touches_missing_note edits monoframe/mf-gone)" ]
}

@test "a creates path may be missing, but its folder may not" {
  brief p2-required makes "Makes." "[]" "[]" "[monoframe/mf-new, nowhere/mf-new]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_creates_folder_missing_note makes nowhere/mf-new)" ]
}

@test "an absolute path or one with a .. segment leaves the root and is never looked at" {
  brief p2-required out "Out." "[]" "[/etc, aidk-plans/../.., ..]" "[../sibling, a/../b]"
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
  brief p2-required Bad_Name "Bad." "[]" "[aidk-plans]" "[]"
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
  brief p2-required here "Here." "[]" "[aidk-plans]" "[]"
  mark gone s1 "$now"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_mark_orphan_note gone)" ]
}

@test "a draft is checked for its summary alone" {
  draft p3-conditional bare-item "Bare."
  printf -- '---\nsummary: Loose.\ndraft: true\nafter: [nowhere, loose-item]\ntouches: [/etc, no-such-folder]\n---\n' >"$plans/p3-conditional/loose-item.md"
  run organizer check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf -- '---\ndraft: true\n---\n# Untitled\n' >"$plans/p4-optional/no-summary.md"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_missing_field_note no-summary summary)" ]
}

# regression: a draft line saying anything but true made the file an ordinary
# brief without a word, offered as ready where its header passed.
@test "a draft in a level no draft may lie in is a problem naming where it may" {
  draft p1-critical urgent-item "Urgent."
  draft p2-required soon-item "Soon."
  draft p4-optional someday "Someday."
  run organizer check
  [ "$status" -eq 1 ]
  expected="$(problem_draft_level_note soon-item p2-required "p3-conditional, p4-optional")
$(problem_draft_level_note urgent-item p1-critical "p3-conditional, p4-optional")"
  [ "$output" = "$expected" ]
}

@test "a draft line saying anything but true is a problem, and the file is never offered" {
  printf -- '---\nsummary: Unsure.\ndraft: yes\nafter: []\ntouches: [aidk-plans]\ncreates: []\n---\n' >"$plans/p2-required/unsure.md"
  printf -- '---\nsummary: Bare.\ndraft: false\n---\n' >"$plans/p4-optional/bare-item.md"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_bad_draft_value_note bare-item false)"$'\n'"$(problem_bad_draft_value_note unsure yes)" ]
  run organizer list
  [ "$status" -eq 1 ]
  [[ "$output" != *"$(list_ready_line unsure p2-required "Unsure.")"* ]]
}

@test "a folder that is no level is a problem, and nothing in it is read" {
  brief p2-required kept "Kept." "[]" "[aidk-plans]" "[]"
  mkdir -p "$plans/p2-requried"
  printf '# No header at all\n' >"$plans/p2-requried/lost.md"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_unknown_level_folder_note p2-requried "p1-critical, p2-required, p3-conditional, p4-optional")" ]
}

@test "a file lying directly in the briefs folder is in no level, and still checked" {
  printf -- '---\nsummary: Flat.\nafter: [nowhere]\ntouches: [aidk-plans]\ncreates: []\n---\n' >"$plans/flat.md"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_in_no_level_note flat)"$'\n'"$(problem_after_missing_note flat nowhere)" ]
}

@test "one name in two levels is a problem naming both" {
  brief p1-critical twice "Once." "[]" "[aidk-plans]" "[]"
  draft p4-optional twice "Twice."
  brief p2-required single "Single." "[]" "[aidk-plans]" "[]"
  run organizer check
  [ "$status" -eq 1 ]
  [ "$output" = "$(problem_name_in_levels_note twice "p1-critical, p4-optional")" ]
}
