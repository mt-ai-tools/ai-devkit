bats_require_minimum_version 1.5.0

# Behavior tests for the drafts command: every draft in full, in level order
# and then name order, or one level's alone; a broken draft left out, as the
# list leaves it out; a level that is not one of the kit's refused before
# anything is read by it.

load project

setup() {
  setup_project
  place aidk-plans
  brief p1-critical a-brief "A brief." "[]" "[aidk-plans]" "[]"
  draft p4-optional aa-someday "Someday."
  draft p1-critical zz-broken-now "Broken now."
  draft p2-required before-release "Before release."
  draft p1-critical aa-blocking "Blocking."
}

@test "every draft is listed in full, in level order and then name order, and no brief is" {
  run --separate-stderr organizer drafts
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  expected="$(drafts_line aa-blocking p1-critical "Blocking.")
$(drafts_line zz-broken-now p1-critical "Broken now.")
$(drafts_line before-release p2-required "Before release.")
$(drafts_line aa-someday p4-optional "Someday.")"
  [ "$output" = "$expected" ]
}

# The form is the list's own line form, spelled here as the list's test
# spells it.
@test "a draft's line names it, then its level in brackets, then its summary" {
  run organizer drafts p2-required
  [ "$status" -eq 0 ]
  [ "$output" = "- before-release [p2-required] — Before release." ]
}

@test "given a level, only that level's drafts are listed" {
  run --separate-stderr organizer drafts p1-critical
  [ "$status" -eq 0 ]
  [ "$output" = "$(drafts_line aa-blocking p1-critical "Blocking.")"$'\n'"$(drafts_line zz-broken-now p1-critical "Broken now.")" ]
  run --separate-stderr organizer drafts p3-conditional
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# Every level is spelled with its meaning: the refusal is where the operator
# reads what the levels mean.
@test "a level that is not one of the four is refused, naming each level with its meaning" {
  meanings="p1-critical (broken or blocking work today); p2-required (must land before the next release); p3-conditional (waits on a named trigger, which the brief or draft writes down); p4-optional (nice to have, or a gap the operator chose to leave)"
  for level in p2-requried ../p1-critical "" P1-CRITICAL; do
    run --separate-stderr organizer drafts "$level"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_bad_level_note "$level" "$meanings")" ]
  done
}

@test "a draft the check finds a problem with is left out, and stderr and the status say so" {
  printf -- '---\ndraft: true\n---\n' >"$plans/p2-required/no-summary.md"
  draft p3-conditional before-release "Twice."
  run --separate-stderr organizer drafts
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(drafts_problems_note)" ]
  expected="$(drafts_line aa-blocking p1-critical "Blocking.")
$(drafts_line zz-broken-now p1-critical "Broken now.")
$(drafts_line aa-someday p4-optional "Someday.")"
  [ "$output" = "$expected" ]
}

@test "more than one level given is refused with the usage" {
  run --separate-stderr organizer drafts p1-critical p2-required
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_usage_note)" ]
}
