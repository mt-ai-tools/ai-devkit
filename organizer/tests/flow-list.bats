# Behavior tests for the header lists: a flow list parses to its trimmed items,
# anything not in brackets is refused, and one item can be taken out and the
# list written back in the header's own form.

setup() {
  . "$BATS_TEST_DIRNAME/../lib/flow-list.sh"
  cd "$BATS_TEST_TMPDIR"
}

@test "a flow list parses to its items, trimmed, empties dropped" {
  run parse_flow_list '[ a,  b/c d ,, e ]'
  [ "$status" -eq 0 ]
  [ "$output" = "a,b/c d,e" ]
  run parse_flow_list '[]'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an item is never expanded against the files around it" {
  touch one two
  run parse_flow_list '[*]'
  [ "$output" = "*" ]
}

@test "a value not in brackets is refused" {
  for value in '' 'a, b' '[a, b' 'a]' '[' '[a]x'; do
    run parse_flow_list "$value"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
  done
}

@test "a list is written back in the header's form" {
  run format_flow_list 'a,b'
  [ "$output" = "[a, b]" ]
  run format_flow_list ''
  [ "$output" = "[]" ]
}

@test "taking an item out keeps the rest in order, and a missing item changes nothing" {
  run without_list_item 'a,b,a,c' a
  [ "$output" = "b,c" ]
  run without_list_item 'a,b' z
  [ "$output" = "a,b" ]
}

@test "a list holds an item only where one equals it whole" {
  run has_list_item 'mount-parts,one' one
  [ "$status" -eq 0 ]
  run has_list_item 'mount-parts,one' mount
  [ "$status" -eq 1 ]
}
