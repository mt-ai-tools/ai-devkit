# Behavior tests for the names: a brief's name and a session's id, and every
# shape that could address a file outside the organizer's folders refused.

setup() {
  . "$BATS_TEST_DIRNAME/../lib/names.sh"
}

@test "a brief's name is lower-case letters, digits and hyphens" {
  run is_brief_name file-trash
  [ "$status" -eq 0 ]
  run is_brief_name 2fa
  [ "$status" -eq 0 ]
}

@test "anything else is no brief's name" {
  for name in '' '../x' 'a/b' '.hidden' '-option' 'Upper' 'a b' 'a.md' $'a\nb'; do
    run is_brief_name "$name"
    [ "$status" -eq 1 ]
  done
}

@test "a session id is letters, digits and hyphens" {
  run is_session_id 3f2a9c1e-0b4d-4e8f-9a7b-1c2d3e4f5a6b
  [ "$status" -eq 0 ]
}

@test "anything else is no session id" {
  for id in '' '../x' 'a b' $'s1\nsince: x' 'a:b'; do
    run is_session_id "$id"
    [ "$status" -eq 1 ]
  done
}

@test "a level's name is one of the four levels" {
  for level in p1-critical p2-required p3-conditional p4-optional; do
    run is_level_name "$level"
    [ "$status" -eq 0 ]
  done
}

@test "anything else is no level's name" {
  for level in '' '../x' 'p2-requried' 'p5-later' 'p1-critical/' 'P1-critical' '.' $'p1-critical\nx'; do
    run is_level_name "$level"
    [ "$status" -eq 1 ]
  done
}
