# Behavior tests for places: only paths inside the root may be named, and a
# ready brief shares a place with a taken one when one path is the other or
# lies inside it, never merely because one name starts with the other, and
# never with another ready brief.

setup() {
  . "$BATS_TEST_DIRNAME/../lib/places.sh"
  us=$'\037'
}

@test "a relative path without .. stays inside the root" {
  for path in monoframe/mf-users aidk-organizer ./a a/..b; do
    run is_inside_root_path "$path"
    [ "$status" -eq 0 ]
  done
}

@test "an absolute path or a .. segment leaves it" {
  for path in /etc .. ../x a/.. a/../b; do
    run is_inside_root_path "$path"
    [ "$status" -eq 1 ]
  done
}

@test "a ready brief in a taken brief's place names it with its age" {
  run derive_same_places <<<"ready${us}trash${us}monoframe/mf-users/${us}
ready${us}frozen${us}monoframe/mf-media,monoframe/mf-users/src${us}
taken${us}held${us}monoframe/mf-users${us}2 h"
  [ "$status" -eq 0 ]
  expected="trash${us}held${us}2 h
frozen${us}held${us}2 h"
  [ "$output" = "$expected" ]
}

@test "two ready briefs sharing a place name neither" {
  run derive_same_places <<<"ready${us}trash${us}monoframe/mf-users${us}
ready${us}frozen${us}monoframe/mf-users/src${us}"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a sibling sharing a prefix, or two taken briefs, share no place" {
  run derive_same_places <<<"ready${us}users${us}monoframe/mf-users${us}
taken${us}old${us}monoframe/mf-users-old${us}1 h
taken${us}a${us}aidk-plans${us}1 h
taken${us}b${us}aidk-plans${us}1 h"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
