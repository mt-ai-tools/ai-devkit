bats_require_minimum_version 1.5.0

# Behavior tests for the taken briefs: every one listed with its holder, and,
# given paths, only those working where one of them lies, a path inside a
# place or a folder holding one, never a sibling sharing a prefix; refused
# whole wherever an answer could leave out a brief that works there.

load project

setup() {
  setup_project
  place aidk-plans
  place monoframe/mf-users
  place monoframe/mf-media
  brief file-trash "Trash." "[]" "[monoframe/mf-media]" "[]"
  brief frozen-account "Frozen." "[]" "[monoframe/mf-users]" "[monoframe/mf-users/src/frozen]"
  brief ready-one "Ready." "[]" "[monoframe/mf-users]" "[]"
  mark file-trash session-1 "$now"
  mark frozen-account session-2 "$now"
}

@test "every taken brief is listed with its holder, in name order" {
  run organizer taken
  [ "$status" -eq 0 ]
  [ "$output" = "file-trash"$'\t'"session-1"$'\n'"frozen-account"$'\t'"session-2" ]
}

@test "given paths, only the briefs working where one of them lies" {
  run organizer taken monoframe/mf-users/src/a.ts
  [ "$status" -eq 0 ]
  [ "$output" = "frozen-account"$'\t'"session-2" ]
  # A brief creating a folder works there as surely as one touching it.
  run organizer taken monoframe/mf-users/src/frozen/b.ts aidk-plans
  [ "$output" = "frozen-account"$'\t'"session-2" ]
  # A folder holding a place holds the work done there.
  run organizer taken monoframe/
  [ "$output" = "file-trash"$'\t'"session-1"$'\n'"frozen-account"$'\t'"session-2" ]
}

@test "a sibling sharing a prefix, or a path nobody works in, names none" {
  run organizer taken monoframe/mf-users-old/a.ts aidk-plans/x.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no marks at all lists nothing" {
  rm -r "$marks"
  run organizer taken monoframe/mf-users
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a mark whose brief is gone is left out" {
  mark gone session-3 "$now"
  run organizer taken
  [ "$status" -eq 0 ]
  [ "$output" = "file-trash"$'\t'"session-1"$'\n'"frozen-account"$'\t'"session-2" ]
}

@test "a path leaving the root is refused, and nothing is listed" {
  for path in /etc ../x monoframe/../../x; do
    run --separate-stderr organizer taken monoframe/mf-users "$path"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_path_outside_note "$path")" ]
  done
}

@test "a mark whose holder cannot be read is refused, whoever it might be" {
  printf 'garbage\n' >"$marks/ready-one"
  run --separate-stderr organizer taken aidk-plans
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_taken_mark_unreadable_note ready-one)" ]
}

@test "a taken brief whose places cannot be read is refused" {
  brief frozen-account "Frozen." "[]" "monoframe/mf-users" "[]"
  run --separate-stderr organizer taken aidk-plans
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_places_unreadable_note frozen-account)" ]
}
