# A throwaway project and a `claude` of the suite's own, so no suite ever asks
# a real model: the fake prints the envelope Claude Code prints, around an
# answer the test chooses, and keeps the arguments and the prompt it was given
# for the test to look at. Loaded by the suites, never run alone.

setup_fake_claude() {
  script="$BATS_TEST_DIRNAME/../bin/stand-in.sh"
  lib="$BATS_TEST_DIRNAME/../lib"
  project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project" "$BATS_TEST_TMPDIR/elsewhere"
  export CLAUDE_PROJECT_DIR="$project"
  cd "$BATS_TEST_TMPDIR/elsewhere"
  fakebin="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$fakebin"
  export FAKE_ARGS="$BATS_TEST_TMPDIR/claude-args"
  export FAKE_PROMPT="$BATS_TEST_TMPDIR/claude-prompt"
  # FAKE_ENVELOPE, when set, is printed as it stands in place of the envelope;
  # FAKE_STATUS is the status the fake ends with; FAKE_SLEEP holds it up.
  cat >"$fakebin/claude" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FAKE_ARGS"
cat >"$FAKE_PROMPT"
[ -n "${FAKE_SLEEP:-}" ] && sleep "$FAKE_SLEEP"
if [ -n "${FAKE_ENVELOPE+set}" ]; then
  printf '%s' "$FAKE_ENVELOPE"
else
  jq -cn --argjson answer "${FAKE_ANSWER:-null}" \
    '{type: "result", is_error: false, result: ($answer | tojson), structured_output: $answer}'
fi
exit "${FAKE_STATUS:-0}"
FAKE
  chmod +x "$fakebin/claude"
  export PATH="$fakebin:$PATH"
}

# A preset of the suite's own, with the kinds and risks given, so no suite
# leans on the kit's own preset: the stand-in must hand over whatever a
# project's preset holds. Kinds as "name:summary" words, a summary of one
# word; risks as names.
preset() {
  local kinds="$1" risks="$2" kind name
  preset_dir="$BATS_TEST_TMPDIR/preset"
  mkdir -p "$preset_dir/questions" "$preset_dir/challenges"
  for kind in $kinds; do
    printf -- '---\nsummary: %s\nroute: ask\n---\n\n# %s\n' "${kind#*:}" "${kind%%:*}" \
      >"$preset_dir/questions/${kind%%:*}.md"
  done
  {
    printf -- '---\nsummary: Risks.\n---\n\n# Risks\n\n'
    for name in $risks; do printf -- '- `%s` — The %s risk.\n' "$name" "$name"; done
  } >"$preset_dir/challenges/risks.md"
  printf 'AIDK_STAND_IN=%s\n' "$preset_dir" >"$project/aidk-config.env"
}

# A whole reader's form asking which of two options, recommending the first.
whole_form() {
  printf '%s' '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"five","claims_done":false,"guidance_answer":""}'
}
