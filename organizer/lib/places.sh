#!/usr/bin/env bash
# What the organizer knows about a brief's places — the paths its touches and
# creates lists name: which may be named at all, and which two are the same
# place. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/flow-list.sh"

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

# A brief's places: its touches and creates together, comma-joined, since a
# brief that brings a folder into being works there as surely as one that
# edits it.
derive_places() {
  local touches creates
  touches="$(parse_flow_list "$1")" || touches=""
  creates="$(parse_flow_list "$2")" || creates=""
  printf '%s' "$touches${touches:+${creates:+,}}$creates"
}

# Whether two paths are the same place, as awk functions every reading of
# places shares, so a ready brief's collision and a path's holder are judged
# alike; why it reads so is said at derive_same_places.
PLACES_SAME_AWK='
  function bare(p) { sub(/\/+$/, "", p); return p }
  function same(a, b) {
    a = bare(a); b = bare(b)
    return a == b || index(a, b "/") == 1 || index(b, a "/") == 1
  }'

# Which ready briefs share a place with a taken one. Each line on stdin is
# "<kind><US><name><US><places><US><age>", kind being `ready` or `taken`,
# places comma-joined, age empty for a ready brief. Each line out is
# "<ready name><US><taken name><US><taken's age>", in the order the briefs came
# in. Rows carry the header reader's separator, since a brief's row is built
# from what that reader hands back.
#
# Two ready briefs are never compared: they collide only once both are worked
# on, and the moment one is taken the other is marked against it. Marking them
# earlier drowned the list, since nearly every brief works somewhere shared.
#
# Two paths are the same place when equal, or when one is the other followed
# by a slash: a brief working in a folder works in everything inside it. The
# slash is what keeps a sibling sharing a prefix (`mf-users-old` beside
# `mf-users`) apart. A trailing slash is ignored, so a writer's habit does not
# change the answer.
derive_same_places() {
  awk -F "$HEADER_US" -v US="$HEADER_US" "$PLACES_SAME_AWK"'
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
          if (kind[j] != "taken" || !overlapping(i, j)) continue
          print name[i] US name[j] US age[j]
        }
      }
    }
  '
}

# Which rows hold any of the paths given. Each line on stdin is
# "<name><US><session><US><places>", places comma-joined; each line out is
# "<name><US><session>" for a row one of whose places is the same place as a
# path, in the order the rows came in. The paths come as arguments, each
# already inside the root. Same place both ways, as a ready brief's collision
# is: a path inside a place lies where that brief works, and a folder holding
# a place holds that work.
derive_places_holding() {
  local paths
  printf -v paths '%s\037' "$@"
  awk -F "$HEADER_US" -v US="$HEADER_US" -v paths="${paths%$'\037'}" "$PLACES_SAME_AWK"'
    BEGIN { count = split(paths, wanted, US) }
    {
      n = split($3, held, ",")
      for (i = 1; i <= n; i++)
        for (j = 1; j <= count; j++)
          if (same(held[i], wanted[j])) { print $1 US $2; next }
    }
  '
}
