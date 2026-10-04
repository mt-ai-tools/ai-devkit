#!/usr/bin/env bash
# How a file's header is read, in one place: the header is the leading block
# delimited by `---` lines, one `name: value` field per line; everything after
# it is the body and is never read as a field. Which fields mean anything is
# the caller's to know — this reader names none. Sourced, never executed.

# The separator between the values it hands back: the ASCII unit separator.
# Not a tab: bash treats tab as IFS whitespace and collapses a run of them, so
# an empty middle field would silently shift the ones after it — which is the
# exact failure callers exist to report.
HEADER_US=$'\037'

# The one-line values of the named fields, in the order asked, joined by
# HEADER_US on one line. A field the header lacks comes back empty rather than
# dropping out, and a file with no header answers every field empty, so the
# caller always gets one value per name and decides what an empty one means.
# A value is the rest of its line, as written: a field whose value continues
# on indented lines (a folded block) yields only its first line, and those
# indented lines are never mistaken for fields of their own. Lists come back
# as written too; parsing them is the caller's.
read_header_fields() {
  local f="$1"
  shift
  local IFS="$HEADER_US"
  # The names reach awk through its environment, not `-v`: `-v` reads
  # backslash escapes, and a name must arrive exactly as the caller spelled it.
  HEADER_WANTED="$*" awk -v US="$HEADER_US" '
    BEGIN { count = split(ENVIRON["HEADER_WANTED"], wanted, US) }
    NR == 1 && $0 != "---" { exit }
    NR == 1 { next }
    $0 == "---" { exit }
    {
      for (i = 1; i <= count; i++) {
        key = wanted[i] ":"
        if (index($0, key) != 1) continue
        rest = substr($0, length(key) + 1)
        sub(/^[[:space:]]*/, "", rest)
        value[i] = rest
      }
    }
    END {
      line = ""
      for (i = 1; i <= count; i++) line = line (i > 1 ? US : "") value[i]
      print line
    }
  ' "$f"
}
