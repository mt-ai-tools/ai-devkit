bats_require_minimum_version 1.5.0

# Behavior tests for the ladder's comparison: the same option from the same
# list on every rung holds, and anything else is a change. The comparison is
# pure, so no model is asked here.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/ladder.sh"
}

# A rung's answer recommending the label given from the options given, as a
# JSON array, five and ten by default.
answer() {
  jq -cn --arg recommended "$1" --argjson options "${2:-[\"five\",\"ten\"]}" \
    '{asks_operator: true, options: $options, recommended: $recommended}'
}

# A ladder holding the answers given, in order.
ladder() {
  printf '%s\n' "$@" | jq -cs '{question: "Five retries or ten?", kind: "defaults", lines: "", answers: .}'
}

@test "a ladder with rungs left climbs" {
  run derive_ladder_step "$(ladder "$(answer five)")"
  [ "$output" = "$LADDER_CLIMB" ]
  run derive_ladder_step "$(ladder "$(answer five)" "$(answer ten)")"
  [ "$output" = "$LADDER_CLIMB" ]
}

@test "the same option from the same list on every rung holds" {
  run derive_ladder_step "$(ladder "$(answer five)" "$(answer five)" "$(answer five)")"
  [ "$output" = "$LADDER_HELD" ]
}

@test "a moved option, a reworded or reordered list, or no recommendation is a change" {
  for last in "$(answer ten)" "$(answer five '["five","twenty"]')" "$(answer five '["ten","five"]')" \
    "$(answer "")" '{"asks_operator":false,"options":[],"recommended":""}' \
    '{"asks_operator":false,"options":["five","ten"],"recommended":"five"}'; do
    run derive_ladder_step "$(ladder "$(answer five)" "$(answer five)" "$last")"
    [ "$output" = "$LADDER_CHANGED" ]
  done
  run derive_ladder_step "$(ladder "$(answer "")" "$(answer "")" "$(answer "")")"
  [ "$output" = "$LADDER_CHANGED" ]
}

@test "each rung after the first sends the next challenge in order" {
  [ "$(to_rung_challenge '["Clean?","Sure?"]' "$(ladder "$(answer five)")")" = "Clean?" ]
  [ "$(to_rung_challenge '["Clean?","Sure?"]' "$(ladder "$(answer five)" "$(answer five)")")" = "Sure?" ]
}
