bats_require_minimum_version 1.5.0

# Behavior tests for the briefs' rows and finding a brief by name: a row for
# every file in every level and every file in none, each carrying its level
# and its draft mark; a name found in exactly one level, never in none or in
# two.

load project

setup() {
  setup_project
  . "$lib/briefs.sh"
  us="$HEADER_US"
}

@test "every row carries its level and its draft mark, in name order" {
  brief p3-conditional when-ready "When." "[]" "[aidk-plans]" "[]"
  draft p3-conditional an-item "Item."
  printf -- '---\nsummary: Flat.\n---\n' >"$plans/flat.md"
  printf '# About the briefs\n' >"$plans/p2-required/README.md"
  run list_brief_rows "$plans"
  [ "$status" -eq 0 ]
  expected="an-item${us}Item.${us}${us}${us}${us}true${us}p3-conditional
flat${us}Flat.${us}${us}${us}${us}${us}
when-ready${us}When.${us}[]${us}[aidk-plans]${us}[]${us}${us}p3-conditional"
  [ "$output" = "$expected" ]
}

@test "a level folder that cannot be listed is refused, never read as holding none" {
  brief p2-required file-trash "Trash." "[]" "[aidk-plans]" "[]"
  chmod 000 "$plans/p2-required"
  run --separate-stderr list_brief_rows "$plans"
  chmod u+rwx "$plans/p2-required"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(collection_unreadable_note "$plans/p2-required")" ]
}

@test "a name is found in the one level holding it" {
  brief p4-optional someday "Someday." "[]" "[aidk-plans]" "[]"
  run find_brief_file "$plans" someday
  [ "$output" = "$plans/p4-optional/someday.md" ]
}

@test "a name in no level, or in two, is found nowhere" {
  printf -- '---\nsummary: Flat.\n---\n' >"$plans/flat.md"
  brief p1-critical twice "Once." "[]" "[aidk-plans]" "[]"
  draft p3-conditional twice "Twice."
  run find_brief_file "$plans" flat
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run find_brief_file "$plans" twice
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
