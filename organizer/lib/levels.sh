#!/usr/bin/env bash
# The levels a brief or a draft sits in, and what each means — the kit's own
# words, the one place they are held, whatever project mounts the kit.
# Sourced, never executed.
#
# A level is a folder inside the briefs folder, and moving a file between them
# is how its priority changes: nothing else records it, so no header field can
# fall out of step with the folder. Each name opens with p and its number, the
# usual priority shorthand, so a plain listing of the folder shows the levels
# in order without the organizer ranking anything itself.

# Every level, in order, as "<name>=<what it means>".
BRIEF_LEVELS=(
  "p1-critical=broken or blocking work today"
  "p2-required=must land before the next release"
  "p3-conditional=waits on a named trigger, which the brief or draft writes down"
  "p4-optional=nice to have, or a gap the operator chose to leave"
)

# The levels' names alone, in the same order, read off the list above.
BRIEF_LEVEL_NAMES=("${BRIEF_LEVELS[@]%%=*}")

# The levels a draft may lie in, each one of the levels above, in their order.
# Small things are fixed on the spot, and big work needed soon is written out
# as a brief at once; a draft is for big work that can wait.
DRAFT_LEVEL_NAMES=(p3-conditional p4-optional)
