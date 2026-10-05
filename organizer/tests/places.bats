# Behavior tests for places: only paths inside the root may be named, and two
# briefs share a place when one path is the other or lies inside it, never
# merely because one name starts with the other.

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

@test "ready briefs sharing a place name each other, and a taken one with its age" {
  run derive_same_places <<<"ready${us}trash${us}monoframe/mf-users/${us}
ready${us}frozen${us}monoframe/mf-media,monoframe/mf-users/src${us}
taken${us}held${us}monoframe/mf-users${us}2 h"
  [ "$status" -eq 0 ]
  expected="trash${us}ready${us}frozen${us}
trash${us}taken${us}held${us}2 h
frozen${us}ready${us}trash${us}
frozen${us}taken${us}held${us}2 h"
  [ "$output" = "$expected" ]
}

@test "a sibling sharing a prefix, or two taken briefs, share no place" {
  run derive_same_places <<<"ready${us}users${us}monoframe/mf-users${us}
ready${us}old${us}monoframe/mf-users-old${us}
taken${us}a${us}aidk-plans${us}1 h
taken${us}b${us}aidk-plans${us}1 h"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
