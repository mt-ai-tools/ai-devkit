#!/usr/bin/env bash
# How a header list is read and written: a one-line flow list, `[a, b]` or
# `[]`. Sourced, never executed.
#
# Inside the organizer a parsed list travels as its items joined by commas.
# A comma is the one character an item can never hold, since the list was
# split on it, so the joined form is unambiguous without any quoting. Lists
# are split with `read -a`, never by an unquoted expansion, so an item such as
# `*` is never expanded against the files in the working directory.

# A list's items, trimmed and joined by commas, empty items dropped; nothing
# printed for `[]`. A value not opening with `[` and closing with `]` is
# refused with a non-zero status and nothing printed: a guess at what a
# half-written list meant is how a brief would come to look ready by mistake.
parse_flow_list() {
  local value="$1" item joined="" items=()
  [[ "$value" == \[*\] ]] || return 1
  IFS=, read -ra items <<<"${value:1:${#value}-2}"
  for item in "${items[@]}"; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [ -n "$item" ] || continue
    joined+="${joined:+,}$item"
  done
  printf '%s' "$joined"
}

# A comma-joined list written back in the header's own form.
format_flow_list() {
  local joined="$1"
  printf '[%s]' "${joined//,/, }"
}

# A comma-joined list with every occurrence of one item taken out.
without_list_item() {
  local joined="$1" drop="$2" item kept="" items=()
  IFS=, read -ra items <<<"$joined"
  for item in "${items[@]}"; do
    [ "$item" = "$drop" ] && continue
    kept+="${kept:+,}$item"
  done
  printf '%s' "$kept"
}

# True if a comma-joined list holds the item.
has_list_item() {
  local joined="$1" want="$2" item items=()
  IFS=, read -ra items <<<"$joined"
  for item in "${items[@]}"; do
    [ "$item" = "$want" ] && return 0
  done
  return 1
}
