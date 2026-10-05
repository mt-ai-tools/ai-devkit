bats_require_minimum_version 1.5.0

# Behavior tests for the list: ready, waiting and taken briefs each in their
# section and in name order, ages from the mark's since, briefs in the same
# place marked, and a broken brief shown among the problems and nowhere else.

load project

setup() {
  setup_project
  place monoframe/mf-users/src
  place monoframe/mf-users-old
  place monoframe/mf-media
  place aidk-plans
}

@test "a brief with nothing to wait on is ready, with its summary" {
  brief file-trash "Deleted files wait before they go." "[]" "[monoframe/mf-media]" "[]"
  run organizer list
  [ "$status" -eq 0 ]
  [ "$output" = "$(list_ready_heading)"$'\n'"$(list_ready_line file-trash "Deleted files wait before they go.")" ]
}

@test "a brief with an after list waits, saying on what" {
  brief one-reporter "One reporter." "[]" "[monoframe/mf-media]" "[]"
  brief mount-parts "Mount parts." "[]" "[aidk-plans]" "[]"
  brief users-going "Users going." "[one-reporter, mount-parts]" "[monoframe/mf-users]" "[]"
  run organizer list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(list_waiting_heading)"$'\n'"$(list_waiting_line users-going "one-reporter, mount-parts")"* ]]
  [[ "$output" != *"$(list_ready_line users-going "Users going.")"* ]]
}

@test "sections come in order, each in name order, parted by a blank line" {
  brief zeta "Zeta." "[]" "[aidk-plans]" "[]"
  brief alpha "Alpha." "[]" "[monoframe/mf-media]" "[]"
  brief waits "Waits." "[alpha]" "[aidk-plans]" "[]"
  brief held "Held." "[]" "[monoframe/mf-users-old]" "[]"
  mark held 0123456789abcdef "2026-10-04T21:15:00Z"
  run organizer list
  [ "$status" -eq 0 ]
  expected="$(list_ready_heading)
$(list_ready_line alpha "Alpha.")
$(list_ready_line zeta "Zeta.")

$(list_waiting_heading)
$(list_waiting_line waits alpha)

$(list_taken_heading)
$(list_taken_line held "15 min" 01234567)"
  [ "$output" = "$expected" ]
}

@test "a taken brief shows its age from the mark: minutes, hours, days" {
  brief fresh "Fresh." "[]" "[monoframe/mf-media]" "[]"
  brief hours "Hours." "[]" "[aidk-plans]" "[]"
  brief stale "Stale." "[]" "[monoframe/mf-users-old]" "[]"
  mark fresh session-fresh-1 "2026-10-04T21:29:30Z"
  mark hours session-hours-1 "2026-10-03T16:30:00Z"
  mark stale session-stale-1 "2026-10-01T09:00:00Z"
  run organizer list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(list_taken_line fresh "0 min" session-)"* ]]
  [[ "$output" == *"$(list_taken_line hours "29 h" session-)"* ]]
  [[ "$output" == *"$(list_taken_line stale "3 d" session-)"* ]]
  [[ "$output" != *"$(list_ready_heading)"* ]]
}

@test "a taken brief is neither ready nor waiting" {
  brief first "First." "[]" "[aidk-plans]" "[]"
  brief second "Second." "[first]" "[monoframe/mf-media]" "[]"
  mark first s1 "$now"
  mark second s2 "$now"
  run organizer list
  [ "$status" -eq 0 ]
  [[ "$output" != *"$(list_ready_heading)"* ]]
  [[ "$output" != *"$(list_waiting_heading)"* ]]
  [[ "$output" == *"$(list_taken_line second "0 min" s2)"* ]]
}

@test "ready briefs in the same place are kept and marked, each naming the other" {
  brief file-trash "Trash." "[]" "[monoframe/mf-users]" "[]"
  brief frozen-account "Frozen." "[]" "[monoframe/mf-users/src]" "[]"
  brief elsewhere "Elsewhere." "[]" "[monoframe/mf-media]" "[]"
  run organizer list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(list_ready_line file-trash "Trash.")"$'\n'"$(list_same_place_ready_line frozen-account)"* ]]
  [[ "$output" == *"$(list_ready_line frozen-account "Frozen.")"$'\n'"$(list_same_place_ready_line file-trash)"* ]]
  [[ "$output" == *"$(list_ready_line elsewhere "Elsewhere.")"$'\n'"$(list_ready_line file-trash "Trash.")"* ]]
}

@test "a ready brief in a taken brief's place is marked with the mark's age" {
  brief file-trash "Trash." "[]" "[monoframe/mf-users/src]" "[]"
  brief frozen-account "Frozen." "[]" "[monoframe/mf-users]" "[]"
  mark frozen-account abc "2026-10-04T19:30:00Z"
  run organizer list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(list_ready_line file-trash "Trash.")"$'\n'"$(list_same_place_taken_line frozen-account "2 h")"* ]]
}

@test "one brief's touches and another's creates are the same place" {
  brief makes "Makes." "[]" "[]" "[monoframe/mf-media/thumbs]"
  brief edits "Edits." "[]" "[monoframe/mf-media]" "[]"
  run organizer list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(list_ready_line edits "Edits.")"$'\n'"$(list_same_place_ready_line makes)"* ]]
  [[ "$output" == *"$(list_ready_line makes "Makes.")"$'\n'"$(list_same_place_ready_line edits)"* ]]
}

@test "a sibling sharing a prefix is not the same place" {
  brief users "Users." "[]" "[monoframe/mf-users]" "[]"
  brief users-old "Old." "[]" "[monoframe/mf-users-old]" "[]"
  run organizer list
  [ "$status" -eq 0 ]
  [[ "$output" != *"same place"* ]]
}

@test "a broken brief is among the problems only, and the rest still lists" {
  brief good "Good." "[]" "[aidk-plans]" "[]"
  brief broken "Broken." "[nowhere]" "[aidk-plans]" "[]"
  brief broken-ready "Broken ready." "[]" "[no-such-folder]" "[]"
  run organizer list
  [ "$status" -eq 1 ]
  [[ "$output" == "$(list_problems_heading)"$'\n'"$(list_problem_line "$(problem_after_missing_note broken nowhere)")"* ]]
  [[ "$output" == *"$(list_problem_line "$(problem_touches_missing_note broken-ready no-such-folder)")"* ]]
  [[ "$output" == *"$(list_ready_line good "Good.")"* ]]
  [[ "$output" != *"$(list_ready_line broken-ready "Broken ready.")"* ]]
  [[ "$output" != *"$(list_waiting_line broken nowhere)"* ]]
}

@test "a brief whose mark cannot be read is never ready" {
  brief held "Held." "[]" "[aidk-plans]" "[]"
  mkdir -p "$marks"
  printf 'garbage\n' >"$marks/held"
  run organizer list
  [ "$status" -eq 1 ]
  [[ "$output" == *"$(problem_mark_unreadable_note held)"* ]]
  [[ "$output" != *"$(list_ready_line held "Held.")"* ]]
}

@test "an empty briefs folder lists nothing, and a missing one is refused" {
  run organizer list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rmdir "$plans"
  run --separate-stderr organizer list
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_no_briefs_folder_note "$plans")" ]
}

@test "a briefs folder set in the config file is the one listed" {
  mkdir -p "$project/docs/plans"
  printf 'AIDK_PLANS=docs/plans\n' >"$project/aidk-config.env"
  printf -- '---\nsummary: Moved.\nafter: []\ntouches: [docs]\ncreates: []\n---\n' >"$project/docs/plans/moved.md"
  run organizer list
  [ "$status" -eq 0 ]
  [ "$output" = "$(list_ready_heading)"$'\n'"$(list_ready_line moved "Moved.")" ]
}

@test "a config file the kit refuses stops the list with the config's reason" {
  . "$BATS_TEST_DIRNAME/../../lib/readers/config.sh"
  printf 'AIDK_ORGANIZER=no-such-folder\n' >"$project/aidk-config.env"
  run --separate-stderr organizer list
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(config_path_missing_note 1 AIDK_ORGANIZER "$project/no-such-folder")" ]
}

@test "an unknown subcommand or a wrong count of words is refused with the usage" {
  run --separate-stderr organizer lsit
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_usage_note)" ]
  run --separate-stderr organizer list extra
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_usage_note)" ]
  run --separate-stderr organizer
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_usage_note)" ]
}
