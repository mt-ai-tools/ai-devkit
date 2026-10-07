#!/usr/bin/env bash
# The rules and conventions check: one question, already read into a checked
# reader's form, read by a fresh model against the full text of every rule and
# every convention entry the project has, before any route is taken; the
# answer checked before anything is decided from it. Sourced, never executed.
#
# It knows no rule and no convention by name: whatever the two collections
# hold is handed over whole, read through the kit's one collection reader, and
# no special case is made for any entry. A summary would let the checker miss
# what only an entry's body says, and a copy in the prompt would drift from the
# entry.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_CHECKER:-}" ] || return 0
STAND_IN_LOADED_CHECKER=1
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/collection.sh"
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The two collections an entry may come from, as the entries list marks them.
CHECK_RULES="rules"
CHECK_CONVENTIONS="conventions"

# --- Transforms.

# The entries' names alone, as a JSON array.
to_entry_names() {
  jq -c 'map(.name) | unique' <<<"$1"
}

# The words sending a question back to the agent for what the checker found,
# given its checked answer and the entries it was handed; nothing where it
# found nothing. Every broken entry is named with where it lies, so the agent
# reads the entry itself rather than a summary of it.
derive_checker_sendback() {
  local answer="$1" entries="$2" lines="" name why collection path what called actually
  while IFS=$'\037' read -r name why; do
    [ -n "$name" ] || continue
    while IFS=$'\037' read -r collection path; do
      [ -n "$path" ] || continue
      what="$(convention_words)"
      [ "$collection" = "$CHECK_RULES" ] && what="$(rule_words)"
      lines+="$(gate_breaks_line "$what" "$name" "$path" "$why")"$'\n'
    done < <(jq -r --arg name "$name" '.[] | select(.name == $name) | [.collection, .path] | join("\u001f")' <<<"$entries")
  done < <(jq -r '.breaks[] | [.entry, .why] | map(gsub("\\s+"; " ")) | join("\u001f")' <<<"$answer")
  while IFS=$'\037' read -r called actually; do
    [ -n "$called" ] || continue
    lines+="$(gate_miscalled_line "$called" "$actually")"$'\n'
  done < <(jq -r '.miscalled[] | [.called, .actually] | map(gsub("\\s+"; " ")) | join("\u001f")' <<<"$answer")
  if jq -e '.explains_code' >/dev/null <<<"$answer"; then
    lines+="$(gate_explains_code_line)"$'\n'
  fi
  [ -n "$lines" ] || return 0
  gate_checker_sendback_note "$lines"
}

# --- Reads.

# The entries the checker reads, as a JSON array of {name, path, collection}:
# every rule, then every convention, given the two collections' folders; a
# refusal on stderr and a non-zero status where there is no rule. A project
# may keep no conventions, and is checked against its rules alone; a check
# with no rule to read would pass every question unread.
list_check_entries() {
  local rules="$1" conventions="$2" collection dir entry rows="" entries
  for collection in "$CHECK_RULES" "$CHECK_CONVENTIONS"; do
    dir="$rules"
    [ "$collection" = "$CHECK_RULES" ] || dir="$conventions"
    while IFS= read -r entry; do
      [ -n "$entry" ] || continue
      rows+="$(jq -cn --arg name "$(basename "$entry")" --arg path "$entry" --arg collection "$collection" \
        '{name: $name, path: $path, collection: $collection}')"$'\n' || return 1
    done < <(list_collection_entries "$dir")
  done
  entries="$(printf '%s' "$rows" | jq -cs .)" || return 1
  if ! jq -e --arg rules "$CHECK_RULES" 'any(.[]; .collection == $rules)' >/dev/null <<<"$entries"; then
    refuse_no_rules_note "$rules" >&2
    return 1
  fi
  printf '%s\n' "$entries"
}

# One collection's entries, each whole under a line naming its file, read
# from the entries list; a refusal on stderr and a non-zero status where one
# cannot be read. An entry left out unseen would be one no question is checked
# against.
read_entry_texts() {
  local entries="$1" collection="$2" name path text
  while IFS=$'\037' read -r name path; do
    [ -n "$path" ] || continue
    if ! text="$(cat "$path" 2>/dev/null)"; then
      refuse_unreadable_file_note "$path" >&2
      return 1
    fi
    printf '=====ENTRY %s=====\n%s\n\n' "$name" "$text"
  done < <(jq -r --arg collection "$collection" \
    '.[] | select(.collection == $collection) | [.name, .path] | join("\u001f")' <<<"$entries")
}

# What the checker is handed the same on every question, given the entries
# list: its instructions and every entry whole. Every long text reaches jq
# through a file descriptor, never as an argument: the rules and conventions
# together outgrow what one argument to a command may hold.
#
# Kept apart from the question so that it reads back from the cache rather than
# being paid in full each time (measured in ask-model.sh): it must hold nothing
# that changes between questions, or no question after the first reads it back.
get_checker_standing() {
  local entries="$1" prose rules conventions values
  prose="$(read_prompt checker)" || return 1
  rules="$(read_entry_texts "$entries" "$CHECK_RULES")" || return 1
  conventions="$(read_entry_texts "$entries" "$CHECK_CONVENTIONS")" || return 1
  values="$(jq -cn \
    --rawfile rules <(printf '%s' "$rules") \
    --rawfile conventions <(printf '%s' "$conventions") \
    '{rules: $rules, conventions: $conventions}')" || return 1
  to_filled_prompt "$PROMPTS_DIR/checker.md" "$prose" "$values"
}

# The checker's prompt for one question, sent after what it is handed the same
# every time, given the reader's form and the reply.
get_checker_question() {
  local form="$1" reply="$2" prose values
  prose="$(read_prompt checker-question)" || return 1
  values="$(jq -cn --arg form "$form" --rawfile reply <(printf '%s' "$reply") \
    '{form: $form, reply: $reply}')" || return 1
  to_filled_prompt "$PROMPTS_DIR/checker-question.md" "$prose" "$values"
}

# The checked checker's answer for one question, as one line of JSON, given
# the reader's form, the reply and the entries list; a refusal naming why on
# stderr and a non-zero status where the form holds no question, an entry
# cannot be read, the model could not be asked, or its answer does not pass.
get_checker_answer() {
  local form reply="$2" entries="$3" names standing prompt schema answer
  form="$(refuse_questionless_form "$1")" || return 1
  names="$(to_entry_names "$entries")" || return 1
  standing="$(get_checker_standing "$entries")" || return 1
  prompt="$(get_checker_question "$form" "$reply")" || return 1
  schema="$(checker_answer_schema "$names")" || return 1
  answer="$(get_model_answer "$CHECKER_MODEL" "$CHECKER_SECONDS" "$schema" "" "" "$standing" <<<"$prompt")" || return 1
  refuse_bad_checker_answer "$answer" "$names"
}
