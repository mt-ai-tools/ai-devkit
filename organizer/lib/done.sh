#!/usr/bin/env bash
# Finishing a brief: the brief is deleted and its name taken out of every other
# brief's after list, so a wait disappears together with what it waited on and
# a name left behind can only ever be a mistake. Sourced, never executed.
#
# It changes files and stops there: it prints every path it deleted or
# changed, and committing exactly those is left to whoever called it.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/flow-list.sh"
. "$(dirname "${BASH_SOURCE[0]}")/briefs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/marks.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# --- Reads.

# The line number of a header field's line, by the header reader's own
# reading: inside the leading `---` block, and the last such line where a
# header repeats one, since that is the value the reader hands back. Nothing
# where the header lacks it.
find_header_line() {
  awk -v key="$2:" '
    NR == 1 && $0 != "---" { exit }
    NR == 1 { next }
    $0 == "---" { exit }
    index($0, key) == 1 { found = NR }
    END { if (found) print found }
  ' "$1"
}

# --- Writes.

# Finish a brief. Every other brief's after list is read first, and one that
# cannot be read refuses the whole finish before anything changes: whether it
# names the brief cannot be told, and a half-made finish would leave a name
# behind that the check then reports as missing. Each waiter is rewritten
# where it lies, whatever its level, or in no level, since the name it waits
# on is gone wherever it is read: written whole to a hidden copy beside it
# and moved into place, its after line rewritten and every other byte copied
# as it stood. A draft brief is never a waiter: its after list is not judged,
# and one it does not hold must not refuse the finish.
finish_brief() {
  local plans="$1" marks="$2" brief="$3" file rows name summary after touches creates draft level items line hidden
  local waiters=() hiddens=() i
  refuse_unknown_brief "$plans" "$brief" || return 1
  # Asked before anything changes: a finish that could not free the mark after
  # deleting the brief would leave a mark naming a brief that is gone.
  refuse_unwritable_marks_dir "$marks" || return 1
  file="$(find_brief_file "$plans" "$brief")"
  rows="$(list_brief_rows "$plans")" || return 1

  while IFS="$HEADER_US" read -r name summary after touches creates draft level; do
    [ -n "$name" ] && [ "$name" != "$brief" ] || continue
    ! is_draft_value "$draft" || continue
    if ! items="$(parse_flow_list "$after")"; then
      refuse_header_unreadable_note "$name" >&2
      return 1
    fi
    has_list_item "$items" "$brief" || continue
    waiters+=("$(brief_path "$plans" "$level" "$name")")
  done <<<"$rows"

  for i in "${!waiters[@]}"; do
    line="$(find_header_line "${waiters[$i]}" after)"
    after="$(read_header_fields "${waiters[$i]}" after)"
    items="$(without_list_item "$(parse_flow_list "$after")" "$brief")"
    hidden="$(dirname "${waiters[$i]}")/.$(basename "${waiters[$i]}" .md).done.$$"
    hiddens+=("$hidden")
    if ! write_with_line "${waiters[$i]}" "$line" "after: $(format_flow_list "$items")" "$hidden"; then
      rm -f "${hiddens[@]}"
      return 1
    fi
  done

  # The mark is freed first of every change, not last: the folder may close
  # between the check above and this removal, and a removal failing here is
  # refused while every brief still stands as it was. Freed last, the same
  # failure left the brief deleted and its waiters rewritten beside a mark
  # naming a brief that is gone; freed first, a later failure leaves at worst
  # a brief untaken, which the list shows and taking it again mends. The mark
  # lives only on this machine and outside version control, so it is freed
  # without being printed: a path printed here is one to commit.
  if ! free_brief "$marks" "$brief"; then
    rm -f "${hiddens[@]}"
    return 1
  fi
  for i in "${!waiters[@]}"; do
    mv "${hiddens[$i]}" "${waiters[$i]}"
  done
  rm "$file"
  printf '%s\n' "$file"
  for i in "${!waiters[@]}"; do
    printf '%s\n' "${waiters[$i]}"
  done
}

# A file's copy at another path with one line replaced, every other byte as it
# stood. `head` and `tail` copy bytes as they are, which a line-by-line
# rewrite would not where the last line has no line ending.
write_with_line() {
  local from="$1" number="$2" text="$3" to="$4"
  [ -n "$number" ] || return 1
  {
    head -n "$((number - 1))" "$from"
    printf '%s\n' "$text"
    tail -n "+$((number + 1))" "$from"
  } >"$to"
}
