#!/usr/bin/env bash
# The two fixed forms the stand-in's agents fill — the reader's and the
# sorter's — in one place: every field and its JSON type, from which both the
# schema a model answers to and the check in code are drawn, so the two can
# never disagree on what a form holds. What each field means is the prompts'
# to say. Sourced, never executed.

# The reader's form. asks_operator: the reply puts a question to the operator
# that waits for their answer. question: that question in one sentence.
# options: the option labels the reply names, in its order. recommended: the
# label it recommends. claims_done: it says the work is finished.
# guidance_answer: its answer to a challenge about proposed guidance.
READER_FORM_FIELDS='{
  "asks_operator": "boolean",
  "question": "string",
  "options": "array",
  "recommended": "string",
  "claims_done": "boolean",
  "guidance_answer": "string"
}'

# The words an answer to a guidance challenge may be, the empty one for a
# reply that answers none. Keeping part of a proposal is told apart from
# keeping all of it so the log shows which, though both count as keeping.
GUIDANCE_ANSWERS='["drop", "keep-part", "keep-all", ""]'

# The sorter's answer. kind: one kind of question from the preset. unsure:
# the sorter could not tell. risks: the preset's risks the recommended option
# carries.
SORTER_ANSWER_FIELDS='{
  "kind": "string",
  "unsure": "boolean",
  "risks": "array"
}'

# --- Transforms.

# A schema for the fields given, every one required and nothing else allowed;
# an array is one of strings. The extras, keyed by field, are merged into that
# field's schema.
to_form_schema() {
  jq -cn --argjson fields "$1" --argjson extras "$2" '{
    type: "object",
    properties: ($fields | with_entries(
      .key as $name
      | .value = (
          (if .value == "array" then {type: "array", items: {type: "string"}} else {type: .value} end)
          * ($extras[$name] // {})
        )
    )),
    required: ($fields | keys_unsorted),
    additionalProperties: false
  }'
}

# The schema the reader answers to.
reader_form_schema() {
  to_form_schema "$READER_FORM_FIELDS" "$(jq -cn --argjson words "$GUIDANCE_ANSWERS" \
    '{guidance_answer: {enum: $words}}')"
}

# The schema the sorter answers to, given the kind names and the risk names
# the preset holds, each as a JSON array.
sorter_answer_schema() {
  to_form_schema "$SORTER_ANSWER_FIELDS" "$(jq -cn --argjson kinds "$1" --argjson risks "$2" \
    '{kind: {enum: $kinds}, risks: {items: {type: "string", enum: $risks}}}')"
}
