#!/usr/bin/env bash
# The closing reader: a reply to one look of the closing loop read by a fresh
# model into its findings, each with the sort the agent gave it, and the form
# checked before anything is decided from it. It reads only; what each sort
# leads to, and what code checks of it, is decided elsewhere. Sourced, never
# executed.
#
# Read alone on a look's reply, as the matcher is on a rung: the reply is
# known to answer the look, so the reader of every other reply is not asked
# what it is (settled 2026-10-06).

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_CLOSING_READER:-}" ] || return 0
STAND_IN_LOADED_CLOSING_READER=1
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"

# What the prompt shows where no other session holds a brief.
CLOSING_NO_BRIEFS="(none)"

# --- Transforms.

# The closing reader's prompt, given the prompt's prose, the reply, the
# briefs other sessions hold as a JSON array of names, and the project's
# root, which the reader is handed so it can write every path from inside the
# project, as the organizer and the check read them.
to_closing_prompt() {
  local prose="$1" reply="$2" briefs="$3" root="$4" values
  values="$(jq -cn --rawfile reply <(printf '%s' "$reply") --arg root "$root" --arg none "$CLOSING_NO_BRIEFS" \
    --argjson briefs "$briefs" \
    '{reply: $reply, root: $root, briefs: (if $briefs == [] then $none else ($briefs | map("- \(.)") | join("\n")) end)}')" || return 1
  to_filled_prompt "$PROMPTS_DIR/closing.md" "$prose" "$values"
}

# --- Reads.

# The checked closing reader's form for one look's reply, as one line of
# JSON, given the reply, the briefs other sessions hold as a JSON array of
# names, and the project's root; a refusal naming why on stderr and a
# non-zero status where the prompt cannot be read, the model could not be
# asked, or its form does not pass.
get_look_form() {
  local reply="$1" briefs="$2" root="$3" prose prompt schema answer
  prose="$(read_prompt closing)" || return 1
  prompt="$(to_closing_prompt "$prose" "$reply" "$briefs" "$root")" || return 1
  schema="$(look_form_schema "$briefs")"
  answer="$(get_model_answer "$CLOSING_MODEL" "$CLOSING_SECONDS" "$schema" <<<"$prompt")" || return 1
  refuse_bad_look_form "$answer" "$briefs"
}
