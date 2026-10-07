#!/usr/bin/env bash
# The trial, and the operator's yes that ends it for a kind: until they say
# yes to a kind, whatever the stand-in would settle without them still comes
# to them, marked with what it would have done, and is counted toward the
# kind's trial; trust is gained on their yes, never assumed. Asked by every
# path that can settle anything — a step's go, a question accepted with no
# challenge, an answer that held under its challenges — so all of them tell a
# switched kind apart in this one place. Sourced, never executed.
#
# The yes is one small file per kind in the project's stand-in folder, which
# the project commits, saying when it was given (settled 2026-10-06, decision
# 9): kept in the kit, it would be one project's trust carried by every
# project that mounts the kit. The kind's route in the preset is never
# changed by it, so the preset stays the operator's judgement alone.
#
# Back to the trial automatically, with notice, once the operator reopens
# some of the decisions the stand-in settled alone of that kind after the
# yes: worked out from the question log each time it is asked, never written
# down (settled 2026-10-06: code deleting the yes file would commit it inside
# whichever session hit the reopen that tipped it). A newer yes starts the
# count again. The two directions differ on purpose: gaining trust needs a
# yes; losing it does not.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_TRIAL:-}" ] || return 0
STAND_IN_LOADED_TRIAL=1
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/question-log.sh"

# The yes files' folder inside the stand-in's working folder. Unlike the rest
# of that folder but as the test cases are, it is committed: the operator's
# yes is worth as much on every machine as on the one it was typed on.
TRUST_SUBFOLDER="trusted"

# The header fields a yes file says its kind and when it was given by.
TRUST_KIND_FIELD="kind"
TRUST_GIVEN_FIELD="given"

# When a yes was given, as the question log writes a moment: UTC to the
# second, so a yes and the lines settled after it compare as text. A file
# saying it any other way is unreadable, never guessed at.
TRUST_GIVEN_PATTERN='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'

# A kind's name as a yes file may be named by it, as the preset's own kinds
# are named. A name outside it never becomes a path, so a log line naming a
# kind like "../x" cannot write outside the folder; such a kind stays on
# trial.
TRUST_KIND_PATTERN='^[a-z0-9]+(-[a-z0-9]+)*$'

# The fall-back (settled 2026-10-01/02, decision 9): back on trial when the
# operator reopens this many of the first this many decisions the stand-in
# settled alone of the kind after its yes. Counted among the first ones only:
# a kind that settled many quietly since earns no slack on a later run of
# reopens, and one that settled few is judged on what it settled.
TRIAL_FALLBACK_REOPENS=2
TRIAL_FALLBACK_WINDOW=20

# --- Transforms.

# The yes files' folder, from the stand-in's working folder.
to_trust_dir() {
  printf '%s/%s\n' "$1" "$TRUST_SUBFOLDER"
}

# A kind's yes file, from the stand-in's working folder and the kind.
to_trust_path() {
  printf '%s/%s.md\n' "$(to_trust_dir "$1")" "$2"
}

# True if the kind given may name a yes file.
is_trust_kind() {
  [[ "$1" =~ $TRUST_KIND_PATTERN ]]
}

# True if the moment given is one a yes file may say it was given at.
is_trust_given() {
  [[ "$1" =~ $TRUST_GIVEN_PATTERN ]]
}

# A yes file's whole text, given the kind and when the yes was given.
to_trust_text() {
  printf -- '---\n%s: %s\n%s: %s\n---\n\n' "$TRUST_KIND_FIELD" "$1" "$TRUST_GIVEN_FIELD" "$2"
  trust_file_body_words "$1"
}

# True if the answer the operator typed is a plain yes: the word alone, in
# any case, with a full stop or an exclamation mark after it at most. Anything
# more is no yes (settled 2026-10-07): "yes, but only for…" is a condition
# nothing here can keep, and a yes read into other words would hand over a
# kind the operator never handed over.
is_plain_yes() {
  local answer
  answer="$(tr '[:upper:]' '[:lower:]' <<<"$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[.!]$//')"
  [ "$answer" = "$(trial_yes_words)" ]
}

# How many of the first decisions the stand-in settled alone of the kind
# given, since the yes given, the operator has reopened, given the log's
# lines. A line is settled at its moment, and reopened where the reopen
# marked it so.
derive_fallback_reopens() {
  local lines="$1" kind="$2" given="$3"
  [ -n "$lines" ] || { printf '0\n'; return 0; }
  jq -s --arg kind "$kind" --arg given "$given" --arg settled "$OUTCOME_SETTLED" \
    --argjson window "$TRIAL_FALLBACK_WINDOW" '
    [.[] | select(.outcome == $settled and .kind == $kind and .when >= $given)]
    | sort_by(.number) | .[0:$window] | map(select(.reopened != null)) | length' <<<"$lines"
}

# True if the kind given is back on trial since the yes given, given the
# log's lines.
is_fallen_back() {
  [ "$(derive_fallback_reopens "$1" "$2" "$3")" -ge "$TRIAL_FALLBACK_REOPENS" ]
}

# The notice that a reopen sent the kind back to the trial, given the log's
# lines before it and after it, the kind and its yes; nothing where it did
# not. Told once (settled 2026-10-01/02, decision 9): only the reopen that
# reaches the count says so, and a later one finds it reached already.
derive_fallback_notice() {
  local before="$1" after="$2" kind="$3" given="$4"
  ! is_fallen_back "$before" "$kind" "$given" || return 0
  is_fallen_back "$after" "$kind" "$given" || return 0
  trial_fallback_note "$kind" "$TRIAL_FALLBACK_REOPENS" "$TRIAL_FALLBACK_WINDOW" "$given"
}

# --- Reads.

# When the operator's yes to the kind given was given, from the stand-in's
# working folder; nothing where they gave none. A refusal on stderr and a
# non-zero status where the kind cannot name a file, or its file cannot be
# read or does not say when in the log's own form.
read_trust_given() {
  local history="$1" kind="$2" file given
  if ! is_trust_kind "$kind"; then
    refuse_trust_kind_note "$kind" >&2
    return 1
  fi
  file="$(to_trust_path "$history" "$kind")"
  [ -e "$file" ] || return 0
  if ! given="$(read_header_fields "$file" "$TRUST_GIVEN_FIELD" 2>/dev/null)" || ! is_trust_given "$given"; then
    refuse_trust_unreadable_note "$file" >&2
    return 1
  fi
  printf '%s\n' "$given"
}

# True while the kind named is on trial, given the stand-in's working folder:
# where the operator gave it no yes, and where they did but have since sent
# it back by reopening its silent decisions. A yes that cannot be read, or a
# log that cannot, leaves the kind on trial: what the stand-in would settle
# then still reaches the operator, which is the side to fail on.
is_on_trial() {
  local history="$1" kind="$2" given lines
  given="$(read_trust_given "$history" "$kind" 2>/dev/null)" || return 0
  [ -n "$given" ] || return 0
  lines="$(list_log_lines "$(to_log_dir "$history")" 2>/dev/null)" || return 0
  is_fallen_back "$lines" "$kind" "$given"
}

# The kinds the operator gave a yes to, one a line, from the stand-in's
# working folder, in name order; nothing where they gave none. Each is a yes
# file's name, whatever its header says.
list_trusted_kinds() {
  local dir file
  dir="$(to_trust_dir "$1")"
  [ -d "$dir" ] || return 0
  for file in "$dir"/*.md; do
    [ -f "$file" ] || continue
    basename "$file" .md
  done
}

# True if no kind stands switched, given the stand-in's working folder: none
# was given a yes, or each one that was is back on trial.
is_every_kind_on_trial() {
  local kind
  while IFS= read -r kind; do
    [ -n "$kind" ] || continue
    is_on_trial "$1" "$kind" || return 1
  done < <(list_trusted_kinds "$1")
}

# --- Writes.

# Keep the operator's yes to the kind given, given the stand-in's working
# folder and when it was given: written to a hidden draft and moved over any
# yes before it, so no reader finds half a file and a newer yes replaces the
# older whole. A yes that cannot be kept is refused on stderr with a non-zero
# status, and no draft left.
write_trust_file() {
  local history="$1" kind="$2" given="$3" file dir draft
  if ! is_trust_kind "$kind"; then
    refuse_trust_kind_note "$kind" >&2
    return 1
  fi
  file="$(to_trust_path "$history" "$kind")"
  dir="$(dirname "$file")"
  draft="$dir/.$(basename "$file").$$"
  if ! mkdir -p "$dir" 2>/dev/null || ! { to_trust_text "$kind" "$given" >"$draft"; } 2>/dev/null \
    || ! mv -f "$draft" "$file" 2>/dev/null; then
    rm -f "$draft" 2>/dev/null || true
    refuse_trust_unwritable_note "$dir" >&2
    return 1
  fi
}
