# Behavior tests for the header reader: the named fields come back in the order
# asked, one value each, and nothing outside the header — a missing one, the
# body, a folded block's lines — is ever read as a field.

setup() {
  . "$BATS_TEST_DIRNAME/../readers/header.sh"
  file="$BATS_TEST_TMPDIR/entry.md"
}

@test "the named fields come back in the order asked" {
  printf -- '---\nsummary: What it is.\nphase: first-app\nafter: [a, b]\n---\n# Entry\n' >"$file"
  run read_header_fields "$file" after summary
  [ "$status" -eq 0 ]
  [ "$output" = "[a, b]"$'\037'"What it is." ]
}

@test "a field the header lacks comes back empty, keeping its place" {
  printf -- '---\nphase: first-app\nafter: [a]\n---\n# Entry\n' >"$file"
  run read_header_fields "$file" phase summary after
  [ "$status" -eq 0 ]
  [ "$output" = "first-app"$'\037\037'"[a]" ]
}

@test "a file with no header answers every field empty" {
  printf '# Entry\nsummary: Not a header.\n' >"$file"
  run read_header_fields "$file" summary phase
  [ "$status" -eq 0 ]
  [ "$output" = $'\037' ]
}

@test "a folded field before the wanted one does not break it" {
  printf -- '---\nphase: first-app\nautonomy: >\n  A folded line.\n  phase: An indented decoy.\nsummary: The real one.\n---\n' >"$file"
  run read_header_fields "$file" phase summary
  [ "$status" -eq 0 ]
  [ "$output" = "first-app"$'\037'"The real one." ]
}

@test "a field written in the body is never read" {
  printf -- '---\nphase: first-app\n---\nsummary: In the body.\n' >"$file"
  run read_header_fields "$file" summary
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
