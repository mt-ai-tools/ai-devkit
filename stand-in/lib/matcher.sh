#!/usr/bin/env bash
# The matcher: a reply on a ladder rung after the first, matched by a fresh
# model against the first rung's option list — which item it now recommends,
# a new choice, or no longer asking — and the answer checked before anything
# is decided from it. It reads only; whether the answers held is compared in
# code. Sourced, never executed.
#
# Why not the reader on every rung: the reader writes each reply's options
# afresh, and live it relabelled them between rungs ("five", then "five
# times") and missed a restated question two times in three, so an exact
# comparison of its labels never held (2026-10-05). The matcher is handed the
# one list every rung is compared against, and never the recommendation it
# is compared with, so it cannot lean toward agreeing.
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"

# --- Transforms.

# The matcher's prompt, given the prompt's prose, the question as first
# asked, its options as a JSON array, and the reply. The question is handed
# too, since whether a reply still asks it cannot be told from the options.
to_matcher_prompt() {
  local prose="$1" question="$2" options="$3" reply="$4" values
  values="$(jq -cn --arg question "$question" \
    --arg options "$(jq -r '.[] | "- \(.)"' <<<"$options")" \
    --rawfile reply <(printf '%s' "$reply") \
    '{question: $question, options: $options, reply: $reply}')"
  to_filled_prompt "$PROMPTS_DIR/matcher.md" "$prose" "$values"
}

# --- Reads.

# The checked matcher's answer for one reply, as one line of JSON, given the
# question as first asked, its options as a JSON array, and the reply; a
# refusal naming why on stderr and a non-zero status where the prompt cannot
# be read, the model could not be asked, or its answer does not pass.
get_matcher_answer() {
  local question="$1" options="$2" reply="$3" prose prompt schema answer
  prose="$(read_prompt matcher)" || return 1
  prompt="$(to_matcher_prompt "$prose" "$question" "$options" "$reply")" || return 1
  schema="$(matcher_answer_schema "$options")"
  answer="$(get_model_answer "$MATCHER_MODEL" "$MATCHER_SECONDS" "$schema" <<<"$prompt")" || return 1
  refuse_bad_matcher_answer "$answer" "$options"
}
