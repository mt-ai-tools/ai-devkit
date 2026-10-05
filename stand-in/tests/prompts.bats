bats_require_minimum_version 1.5.0

# Behavior tests for making a prompt: each placeholder filled once with what
# it was handed, a value never searched for placeholders of its own, and a
# placeholder with nothing to fill it refused.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/prompts.sh"
}

@test "each placeholder is filled with its value" {
  run to_filled_prompt p.md $'Kinds:\n{{kinds}}\nReply:\n{{reply}}' '{"kinds":"- a: A.","reply":"Hello."}'
  [ "$status" -eq 0 ]
  [ "$output" = $'Kinds:\n- a: A.\nReply:\nHello.' ]
}

@test "a reply holding a placeholder is handed over as written" {
  run to_filled_prompt p.md 'Reply: {{reply}} Kinds: {{kinds}}' '{"kinds":"K","reply":"see {{kinds}}"}'
  [ "$status" -eq 0 ]
  [ "$output" = 'Reply: see {{kinds}} Kinds: K' ]
}

@test "a placeholder with no value is refused" {
  run --separate-stderr to_filled_prompt p.md 'Reply: {{reply}} {{form}}' '{"reply":"R"}'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_unknown_placeholder_note p.md)" ]
}

@test "the stand-in's own prompts read, and a missing one is refused" {
  run read_prompt reader
  [ "$status" -eq 0 ]
  run --separate-stderr read_prompt nonesuch
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unreadable_file_note "$PROMPTS_DIR/nonesuch.md")" ]
}
