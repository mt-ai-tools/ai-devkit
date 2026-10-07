bats_require_minimum_version 1.5.0

# Behavior tests for the side-by-side runner: every item is run, each writing
# only its own output, never more at once than asked; without GNU parallel
# the items run one at a time and give the same output; a failing item is
# seen, and the items around it still run; what cannot be run is refused.

setup() {
  . "$BATS_TEST_DIRNAME/../runners/side-by-side.sh"
  folder="$BATS_TEST_TMPDIR/runs"
  mkdir "$folder"
  counts="$BATS_TEST_TMPDIR/counts"
  mkdir "$counts"
  export COUNTS="$counts"
  # The call the items make: it counts itself in under a lock, notes how
  # many items were in at once, holds a while, and counts itself out; it
  # prints the item and its arguments, and fails where the item says so.
  library="$BATS_TEST_TMPDIR/item.sh"
  cat >"$library" <<'EOF'
count_item() {
  local in
  exec 8>>"$COUNTS/lock"
  flock 8
  in=$(( $(cat "$COUNTS/in" 2>/dev/null || echo 0) + 1 ))
  echo "$in" >"$COUNTS/in"
  echo "$in" >>"$COUNTS/seen"
  flock -u 8
  sleep "${HOLD:-0}"
  flock 8
  echo $(( $(cat "$COUNTS/in") - 1 )) >"$COUNTS/in"
  flock -u 8
  printf '%s|' "$@"
  printf '\n'
  printf 'said by %s\n' "${!#}" >&2
  [ "${!#}" != fail ] || return 3
}
EOF
}

# The most items that were in at once.
most_at_once() {
  sort -n "$counts/seen" | tail -n 1
}

# A PATH holding every program the one in force holds but GNU parallel.
path_without_parallel() {
  local bin="$BATS_TEST_TMPDIR/no-parallel" dir
  mkdir -p "$bin"
  IFS=: read -ra dirs <<<"$PATH"
  for ((i = ${#dirs[@]} - 1; i >= 0; i--)); do
    dir="${dirs[$i]}"
    [ -d "$dir" ] || continue
    ln -sf "$dir"/* "$bin"/ 2>/dev/null || true
  done
  rm -f "$bin/parallel"
  printf '%s\n' "$bin"
}

@test "every item runs, its output kept under its place in the list" {
  run run_side_by_side 3 "$folder" "$library" count_item one 'two words' <<<$'a\nb b\n\nc'
  [ "$status" -eq 0 ]
  [ "$(cat "$(to_side_by_side_output "$folder" 1)")" = "one|two words|a|" ]
  [ "$(cat "$(to_side_by_side_output "$folder" 2)")" = "one|two words|b b|" ]
  [ "$(cat "$(to_side_by_side_output "$folder" 3)")" = "one|two words|c|" ]
  [ "$(cat "$(to_side_by_side_errors "$folder" 3)")" = "said by c" ]
  [ ! -e "$(to_side_by_side_output "$folder" 4)" ]
}

@test "an argument holding braces reaches the call as written" {
  run run_side_by_side 2 "$folder" "$library" count_item '{}' '{"a":{}}' '{#}' <<<'x'
  [ "$status" -eq 0 ]
  [ "$(cat "$(to_side_by_side_output "$folder" 1)")" = '{}|{"a":{}}|{#}|x|' ]
}

@test "never more items at once than asked, and as many as asked where there are enough" {
  [ -n "$(find_side_by_side_program)" ] || skip "GNU parallel is not installed"
  HOLD=1 run run_side_by_side 2 "$folder" "$library" count_item <<<$'a\nb\nc\nd\ne'
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$counts/seen")" -eq 5 ]
  [ "$(most_at_once)" -eq 2 ]
}

@test "without GNU parallel the items run one at a time, with the same output" {
  PATH="$(path_without_parallel)"
  [ -z "$(find_side_by_side_program)" ]
  HOLD=0.2 run run_side_by_side 4 "$folder" "$library" count_item one <<<$'a\nfail\nc'
  [ "$status" -eq "$SIDE_BY_SIDE_ITEM_FAILED" ]
  [ "$(most_at_once)" -eq 1 ]
  [ "$(cat "$(to_side_by_side_output "$folder" 1)")" = "one|a|" ]
  [ "$(cat "$(to_side_by_side_output "$folder" 2)")" = "one|fail|" ]
  [ "$(cat "$(to_side_by_side_output "$folder" 3)")" = "one|c|" ]
}

@test "a program of the name that is not GNU parallel is not taken for it" {
  bin="$BATS_TEST_TMPDIR/other"
  mkdir "$bin"
  printf '#!/usr/bin/env bash\necho "parallel from moreutils"\n' >"$bin/parallel"
  chmod +x "$bin/parallel"
  PATH="$bin:$PATH" run find_side_by_side_program
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a failing item is seen, its words kept, and the items around it still run" {
  run run_side_by_side 2 "$folder" "$library" count_item <<<$'a\nfail\nc'
  [ "$status" -eq "$SIDE_BY_SIDE_ITEM_FAILED" ]
  [ "$(cat "$(to_side_by_side_errors "$folder" 2)")" = "said by fail" ]
  [ "$(cat "$(to_side_by_side_output "$folder" 1)")" = "a|" ]
  [ "$(cat "$(to_side_by_side_output "$folder" 3)")" = "c|" ]
}

@test "an item runs as under a kit entry: a failing command inside a substitution stops it" {
  cat >"$library" <<'EOF'
stops_early() {
  local x
  x="$(false; echo reached)"
  echo "$x"
}
EOF
  run run_side_by_side 1 "$folder" "$library" stops_early <<<'a'
  [ "$status" -eq "$SIDE_BY_SIDE_ITEM_FAILED" ]
  [ -z "$(cat "$(to_side_by_side_output "$folder" 1)")" ]
}

@test "no items runs nothing" {
  run run_side_by_side 2 "$folder" "$library" count_item <<<''
  [ "$status" -eq 0 ]
  [ ! -e "$counts/seen" ]
}

@test "a count, a folder or a file that cannot be used is refused, and nothing is run" {
  run --separate-stderr run_side_by_side 0 "$folder" "$library" count_item <<<'a'
  [ "$status" -eq "$SIDE_BY_SIDE_REFUSED" ]
  [ "$stderr" = "$(side_by_side_jobs_note 0)" ]
  run --separate-stderr run_side_by_side 2 "$BATS_TEST_TMPDIR/nowhere" "$library" count_item <<<'a'
  [ "$status" -eq "$SIDE_BY_SIDE_REFUSED" ]
  [ "$stderr" = "$(side_by_side_folder_note "$BATS_TEST_TMPDIR/nowhere")" ]
  run --separate-stderr run_side_by_side 2 "$folder" "$BATS_TEST_TMPDIR/none.sh" count_item <<<'a'
  [ "$status" -eq "$SIDE_BY_SIDE_REFUSED" ]
  [ "$stderr" = "$(side_by_side_library_note "$BATS_TEST_TMPDIR/none.sh")" ]
  [ ! -e "$counts/seen" ]
}
