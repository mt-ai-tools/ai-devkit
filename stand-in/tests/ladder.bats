bats_require_minimum_version 1.5.0

# Behavior tests for the ladder's comparison: every rung after the first
# matched to the first rung's recommended item holds, and anything else is a
# change. The comparison is pure, so no model is asked here.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/ladder.sh"
}

# The matcher's pick of a reply: an item of the first list, or the word
# given.
item() { jq -cn --arg item "$1" '{pick: "item", item: $item}'; }
new() { printf '%s' '{"pick":"new","item":""}'; }
gone() { printf '%s' '{"pick":"not-asking","item":""}'; }

# A ladder whose first rung recommends the label given from five and ten,
# holding the picks given, in order; it climbs the route in the variable
# route, the ladder where none is set.
ladder() {
  local recommended="$1"
  shift
  printf '%s\n' "$@" | jq -cs --arg recommended "$recommended" --arg route "${route:-ladder}" \
    '{question: "Five retries or ten?", kind: "defaults", route: $route, lines: "",
      first: {options: ["five", "ten"], recommended: $recommended}, picks: map(select(. != null))}'
}

@test "a ladder with rungs left climbs" {
  run derive_ladder_step "$(ladder five)"
  [ "$output" = "$LADDER_CLIMB" ]
  run derive_ladder_step "$(ladder five "$(item ten)")"
  [ "$output" = "$LADDER_CLIMB" ]
}

@test "every later rung picking the first rung's recommended item holds" {
  run derive_ladder_step "$(ladder five "$(item five)" "$(item five)")"
  [ "$output" = "$LADDER_HELD" ]
}

@test "a moved item, a new choice, a question let go, or no first recommendation is a change" {
  for last in "$(item ten)" "$(new)" "$(gone)"; do
    run derive_ladder_step "$(ladder five "$(item five)" "$last")"
    [ "$output" = "$LADDER_CHANGED" ]
    run derive_ladder_step "$(ladder five "$last" "$(item five)")"
    [ "$output" = "$LADDER_CHANGED" ]
  done
  run derive_ladder_step "$(ladder "" "$(item five)" "$(item five)")"
  [ "$output" = "$LADDER_CHANGED" ]
}

@test "the picks after the rungs, to the bigger look and to \"are you sure?\" once more, never decide" {
  run is_ladder_held "$(ladder five "$(item five)" "$(item five)" "$(item ten)" "$(item ten)")"
  [ "$status" -eq 0 ]
  # An answer that moved once never approves, however it held afterwards.
  run is_ladder_held "$(ladder five "$(item five)" "$(item ten)" "$(item five)" "$(item five)")"
  [ "$status" -eq 1 ]
}

@test "the answer to the bigger look holds when \"are you sure?\" once more picks the same item" {
  run is_look_held "$(ladder five "$(item five)" "$(item ten)" "$(item ten)" "$(item ten)")"
  [ "$status" -eq 0 ]
  run is_look_held "$(ladder five "$(item five)" "$(item ten)" "$(item five)" "$(item five)")"
  [ "$status" -eq 0 ]
}

@test "the answer to the bigger look moved again where the next pick is another item, a new choice, or none yet" {
  for again in "$(item five)" "$(new)" "$(gone)"; do
    run is_look_held "$(ladder five "$(item five)" "$(item ten)" "$(item ten)" "$again")"
    [ "$status" -eq 1 ]
  done
  # Two new choices are never the same: neither is an item of the first list.
  run is_look_held "$(ladder five "$(item five)" "$(item ten)" "$(new)" "$(new)")"
  [ "$status" -eq 1 ]
  run is_look_held "$(ladder five "$(item five)" "$(item ten)" "$(item ten)")"
  [ "$status" -eq 1 ]
}

@test "\"are you sure?\" once more sends the rung's own words, and every other round its own" {
  [ "$(to_round_message_name "$LADDER_SURE_AGAIN")" = are-you-sure ]
  [ "$LADDER_SURE_AGAIN" != are-you-sure ]
  [ "$(to_round_message_name bigger-look)" = bigger-look ]
}

@test "each rung after the first sends the next challenge by its name, in order" {
  [ "$(to_rung_message_name "$(ladder five)")" = standing-test ]
  [ "$(to_rung_message_name "$(ladder five "$(item five)")")" = are-you-sure ]
}

@test "the answers read in order, the bigger look's and the one after it marked as such" {
  run derive_answer_lines "$(ladder five "$(item ten)" "$(new)" "$(gone)" "$(item five)")"
  [ "$status" -eq 0 ]
  expected="$(gate_answer_line 1 five "five${LADDER_OPTION_SEPARATOR}ten")"$'\n'
  expected+="$(gate_pick_line 2 ten)"$'\n'
  expected+="$(gate_pick_new_line 3)"$'\n'
  expected+="$(gate_answer_gone_line "$(gate_looked_number 4)")"$'\n'
  expected+="$(gate_pick_line "$(gate_sure_again_number 5)" five)"
  [ "$output" = "$expected" ]
}

@test "the light check asks \"are you sure?\" alone: one pick decides, held or moved" {
  route=light
  [ "$(to_rung_message_name "$(ladder five)")" = are-you-sure ]
  run derive_ladder_step "$(ladder five)"
  [ "$output" = "$LADDER_CLIMB" ]
  run derive_ladder_step "$(ladder five "$(item five)")"
  [ "$output" = "$LADDER_HELD" ]
  [ "$(to_ladder_rungs "$(ladder five)")" -eq 2 ]
  for last in "$(item ten)" "$(new)" "$(gone)"; do
    run derive_ladder_step "$(ladder five "$last")"
    [ "$output" = "$LADDER_CHANGED" ]
  done
  route=ladder
  [ "$(to_ladder_rungs "$(ladder five)")" -eq 3 ]
}

@test "a ladder climbing a route that climbs none is refused, never read as either" {
  route=ask
  run --separate-stderr derive_ladder_step "$(ladder five "$(item five)")"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_ladder_route_note ask)" ]
  run --separate-stderr to_rung_message_name "$(ladder five)"
  [ "$status" -eq 1 ]
}
