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
# holding the picks given, in order.
ladder() {
  local recommended="$1"
  shift
  printf '%s\n' "$@" | jq -cs --arg recommended "$recommended" \
    '{question: "Five retries or ten?", kind: "defaults", lines: "",
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

@test "a pick after the rungs, the bigger look's, never decides" {
  run is_ladder_held "$(ladder five "$(item five)" "$(item five)" "$(item ten)")"
  [ "$status" -eq 0 ]
  run is_ladder_held "$(ladder five "$(item five)" "$(item ten)" "$(item five)")"
  [ "$status" -eq 1 ]
}

@test "each rung after the first sends the next challenge by its name, in order" {
  [ "$(to_rung_message_name "$(ladder five)")" = standing-test ]
  [ "$(to_rung_message_name "$(ladder five "$(item five)")")" = are-you-sure ]
}

@test "the answers read in order, the bigger look's marked as such" {
  run derive_answer_lines "$(ladder five "$(item ten)" "$(new)" "$(gone)")"
  [ "$status" -eq 0 ]
  expected="$(gate_answer_line 1 five "five${LADDER_OPTION_SEPARATOR}ten")"$'\n'
  expected+="$(gate_pick_line 2 ten)"$'\n'
  expected+="$(gate_pick_new_line 3)"$'\n'
  expected+="$(gate_answer_gone_line "$(gate_looked_number 4)")"
  [ "$output" = "$expected" ]
}
