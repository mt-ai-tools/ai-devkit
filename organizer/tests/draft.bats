bats_require_minimum_version 1.5.0

# Behavior tests for the draft command: a draft written into its level, in the
# shape the check holds a draft to, then counted and listed; every refusal
# writing nothing; and a file already standing never overwritten, whoever put
# it there first.

load project

setup() {
  setup_project
  place aidk-plans
  brief p2-required a-brief "A brief." "[]" "[aidk-plans]" "[]"
  draft p3-conditional an-item "An item."
}

# Every entry of a level folder, hidden ones too, one per line.
level_entries() {
  ls -A "$plans/$1"
}

# The draft's header lines are spelled as the header reader and the check
# read them, since they are the form another part of the kit reads back.
@test "a draft is written into its level, from the summary and text handed in, and its path printed" {
  run --separate-stderr organizer draft p1-critical new-item <<<$'Something broke.\n# Something broke today\n\nThe item\'s own lines.\nTwo of them.'
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$plans/p1-critical/new-item.md" ]
  [ "$(cat "$plans/p1-critical/new-item.md")" = $'---\nsummary: Something broke.\ndraft: true\n---\n\n# Something broke today\n\nThe item\'s own lines.\nTwo of them.' ]
  [ "$(level_entries p1-critical)" = "new-item.md" ]
}

@test "a draft written passes the check, and is counted by the list and shown by drafts" {
  run organizer draft p1-critical new-item <<<$'Something broke.\n# Something broke today'
  [ "$status" -eq 0 ]
  run --separate-stderr organizer check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run --separate-stderr organizer list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(list_unwritten_heading)
$(list_unwritten_named_line p1-critical 1 new-item)
$(list_unwritten_count_line p2-required 0)
$(list_unwritten_count_line p3-conditional 1)
$(list_unwritten_count_line p4-optional 0)" ]]
  run --separate-stderr organizer drafts
  [ "$status" -eq 0 ]
  [ "$output" = "$(drafts_line new-item p1-critical "Something broke.")"$'\n'"$(drafts_line an-item p3-conditional "An item.")" ]
}

@test "a draft may be a summary and a title alone" {
  run organizer draft p4-optional bare <<<$'Bare.\n# Bare'
  [ "$status" -eq 0 ]
  [ "$(cat "$plans/p4-optional/bare.md")" = $'---\nsummary: Bare.\ndraft: true\n---\n\n# Bare' ]
}

@test "a level that is not one of the four is refused, and nothing is written" {
  meanings="p1-critical (broken or blocking work today); p2-required (must land before the next release); p3-conditional (waits on a named trigger, which the brief or draft writes down); p4-optional (nice to have, or a gap the operator chose to leave)"
  for level in p2-requried ../p1-critical "" P1-CRITICAL; do
    run --separate-stderr organizer draft "$level" new-item <<<$'S.\n# T'
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_bad_level_note "$level" "$meanings")" ]
  done
  [ -z "$(find "$project" -name 'new-item*')" ]
}

@test "a name that is no brief's name is refused, and nothing is written" {
  for name in ../x a/b .hidden -option Upper "" a.md; do
    run --separate-stderr organizer draft p2-required "$name" <<<$'S.\n# T'
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_bad_name_note "$name")" ]
  done
  [ "$(level_entries p2-required)" = "a-brief.md" ]
}

@test "a name already standing in any level is refused, naming the level, and the file is left as it was" {
  cp "$plans/p3-conditional/an-item.md" "$BATS_TEST_TMPDIR/an-item.md"
  run --separate-stderr organizer draft p1-critical an-item <<<$'S.\n# T'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_draft_name_taken_note an-item p3-conditional)" ]
  run --separate-stderr organizer draft p3-conditional an-item <<<$'S.\n# T'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_draft_name_taken_note an-item p3-conditional)" ]
  cmp "$plans/p3-conditional/an-item.md" "$BATS_TEST_TMPDIR/an-item.md"
  run --separate-stderr organizer draft p4-optional a-brief <<<$'S.\n# T'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_draft_name_taken_note a-brief p2-required)" ]
  [ -z "$(level_entries p1-critical)" ]
  [ -z "$(level_entries p4-optional)" ]
}

@test "a name lying directly in the briefs folder is refused, and nothing is written" {
  printf -- '---\nsummary: Flat.\ndraft: true\n---\n' >"$plans/flat.md"
  run --separate-stderr organizer draft p2-required flat <<<$'S.\n# T'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_draft_name_in_no_level_note flat)" ]
  [ "$(level_entries p2-required)" = "a-brief.md" ]
}

@test "a missing level folder is refused and never made" {
  rmdir "$plans/p1-critical"
  run --separate-stderr organizer draft p1-critical new-item <<<$'S.\n# T'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_no_level_folder_note p1-critical "$plans")" ]
  [ ! -e "$plans/p1-critical" ]
}

@test "no summary handed in is refused, and nothing is written" {
  for input in "" $'\n# T' ; do
    run --separate-stderr organizer draft p1-critical new-item <<<"$input"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_draft_no_summary_note)" ]
  done
  run --separate-stderr organizer draft p1-critical new-item </dev/null
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_draft_no_summary_note)" ]
  [ -z "$(level_entries p1-critical)" ]
}

# Each the header could not hold: a folded marker, a leading space the reader
# drops, and control characters, among them a line ending from another system
# and the separator the organizer's own rows are parted by.
@test "a summary the header cannot hold as written is refused, and nothing is written" {
  for summary in '>' '|-' '>+2' ' Leading space.' '   ' $'Tab\there.' $'Ends in a return.\r' $'Unit\037separator.'; do
    run --separate-stderr organizer draft p1-critical new-item <<<"$summary"$'\n# T'
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_draft_bad_summary_note)" ]
  done
  [ -z "$(level_entries p1-critical)" ]
}

# A summary carried over two lines reads its second as the text, which then
# opens with no title.
@test "text that does not open with its title line is refused, a summary over two lines among them" {
  for text in "" "Body." "#Title" "# " "## Title" $'Summary, continued.\n# T'; do
    run --separate-stderr organizer draft p1-critical new-item <<<"Summary."$'\n'"$text"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_draft_no_title_note)" ]
  done
  run --separate-stderr organizer draft p1-critical new-item <<<"Summary only."
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_draft_no_title_note)" ]
  [ -z "$(level_entries p1-critical)" ]
}

# Two sessions racing for one name: an `ln` of the suite's own, first on the
# organizer's path, lets the other session's file land first, after every
# check has passed, then links as the real one would.
@test "a file put in place by another session after the checks is never overwritten, and no hidden copy is left" {
  real_ln="$(command -v ln)"
  printf '#!/usr/bin/env bash\nprintf "theirs\\n" >"$2"\nexec %s "$@"\n' "$real_ln" >"$fakebin/ln"
  chmod +x "$fakebin/ln"
  run --separate-stderr organizer draft p1-critical new-item <<<$'Mine.\n# Mine'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_draft_name_taken_note new-item p1-critical)" ]
  [ "$(cat "$plans/p1-critical/new-item.md")" = "theirs" ]
  [ "$(level_entries p1-critical)" = "new-item.md" ]
}

@test "a draft that cannot be linked into place is refused in words, leaving nothing" {
  printf '#!/usr/bin/env bash\nexit 1\n' >"$fakebin/ln"
  chmod +x "$fakebin/ln"
  run --separate-stderr organizer draft p1-critical new-item <<<$'S.\n# T'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_draft_not_written_note "$plans/p1-critical/new-item.md")" ]
  [ -z "$(level_entries p1-critical)" ]
}

@test "a level folder that cannot be written is refused in words, leaving nothing" {
  chmod 555 "$plans/p1-critical"
  run --separate-stderr organizer draft p1-critical new-item <<<$'S.\n# T'
  chmod u+w "$plans/p1-critical"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_draft_not_written_note "$plans/p1-critical/new-item.md")" ]
  [ -z "$(level_entries p1-critical)" ]
}

@test "a level or a name missing, or one more argument, is refused with the usage" {
  for args in "p1-critical" "p1-critical new-item extra"; do
    # shellcheck disable=SC2086
    run --separate-stderr organizer draft $args <<<$'S.\n# T'
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_usage_note)" ]
  done
  [ -z "$(level_entries p1-critical)" ]
}
