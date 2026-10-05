#!/usr/bin/env bash
# What the organizer knows about a brief's places — the paths its touches and
# creates lists name: which may be named at all, and which two are the same
# place. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"

# True if a path stays inside the project root as written: relative, and with
# no `..` segment. Every path a brief names is read from the root, and one that
# escapes it would let a brief's header make the check look at, and judge by,
# any file on the machine.
is_inside_root_path() {
  local path="$1"
  case "$path" in
    /*) return 1 ;;
    .. | ../* | */.. | */../*) return 1 ;;
  esac
  return 0
}

# Which ready briefs share a place with another ready brief or a taken one.
# Each line on stdin is "<kind><US><name><US><places><US><age>", kind being
# `ready` or `taken`, places comma-joined, age empty for a ready brief. Each
# line out is "<ready name><US><kind><US><other name><US><other's age>", in the
# order the briefs came in. Rows carry the header reader's separator, since a
# brief's row is built from what that reader hands back.
#
# Two paths are the same place when equal, or when one is the other followed
# by a slash: a brief working in a folder works in everything inside it. The
# slash is what keeps a sibling sharing a prefix (`mf-users-old` beside
# `mf-users`) apart. A trailing slash is ignored, so a writer's habit does not
# change the answer.
derive_same_places() {
  awk -F "$HEADER_US" -v US="$HEADER_US" '
    function bare(p) { sub(/\/+$/, "", p); return p }
    function same(a, b) {
      a = bare(a); b = bare(b)
      return a == b || index(a, b "/") == 1 || index(b, a "/") == 1
    }
    function overlapping(i, j,   ni, nj, pi, pj, x, y) {
      ni = split(places[i], pi, ",")
      nj = split(places[j], pj, ",")
      for (x = 1; x <= ni; x++)
        for (y = 1; y <= nj; y++)
          if (same(pi[x], pj[y])) return 1
      return 0
    }
    { count++; kind[count] = $1; name[count] = $2; places[count] = $3; age[count] = $4 }
    END {
      for (i = 1; i <= count; i++) {
        if (kind[i] != "ready") continue
        for (j = 1; j <= count; j++) {
          if (j == i || !overlapping(i, j)) continue
          print name[i] US kind[j] US name[j] US age[j]
        }
      }
    }
  '
}
