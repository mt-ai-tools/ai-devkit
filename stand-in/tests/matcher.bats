bats_require_minimum_version 1.5.0

# Behavior tests for the matcher: asked on its own model, handed the first
# question, its options and the reply but never the recommendation compared
# with, made to answer with an item of those options, and refused where its
# answer does not pass. Claude Code is the suite's own fake.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/matcher.sh"
  reply="Let's stay with five tries, it is plenty."
}

@test "the matcher picks among the first options, asked on its model with the question and the reply" {
  answer_for matcher '{"pick":"item","item":"five"}'
  run get_matcher_answer "Five retries or ten?" '["five","ten"]' "$reply"
  [ "$status" -eq 0 ]
  [ "$output" = '{"pick":"item","item":"five"}' ]
  [ "$(calls)" = "matcher $MATCHER_MODEL" ]
  prompt="$FAKE_PROMPT.matcher"
  grep -qxF "Five retries or ten?" "$prompt"
  grep -qxF -- "- five" "$prompt"
  grep -qxF -- "- ten" "$prompt"
  grep -qxF -- "$reply" "$prompt"
  grep -qF -- '"enum":["","five","ten"]' "$FAKE_ARGS.matcher"
}

@test "an answer naming an item off the list is refused, and a model out of time too" {
  answer_for matcher '{"pick":"item","item":"5 attempts"}'
  run --separate-stderr get_matcher_answer "Five retries or ten?" '["five","ten"]' "$reply"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_item_outside_note "5 attempts")" ]
  status_for matcher 124
  run --separate-stderr get_matcher_answer "Five retries or ten?" '["five","ten"]' "$reply"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_model_timeout_note "$MATCHER_MODEL" "$MATCHER_SECONDS")" ]
}
