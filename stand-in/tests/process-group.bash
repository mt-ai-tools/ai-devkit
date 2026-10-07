# A command the suites run in the background, such as a session's wait,
# started as a process group of its own and stopped whole, so no test leaves
# any of it running once the test ends. Loaded by the suites, never run alone.
#
# The group, never the one process: a watch runs its looks in subshells and
# sleeps of their own, which a kill of the shell that started them leaves
# running, orphaned, for as long as the wait they watch stays open (two such
# watches were found still running after a suite, 2026-10-07).

# Start the command given in the background, as a process group of its own,
# its process left in watcher, which is the group's id too. Job control is
# what gives it a group of its own, and is on only while it starts: bash sets
# the group in the parent and the child both, so the id holds before the
# command has run a line. Its descriptor 3, which bats reads the suite's
# output from, is closed, so nothing left over holds that open.
start_in_group() {
  set -m
  "$@" 3>&- &
  watcher=$!
  set +m
}

# Stop the group start_in_group started, where it did, and every process in
# it; refused, naming each one left, where any outlives a few seconds, so the
# test that would leave one running fails. Asked even of a group whose first
# process ended by itself: what it started may not have.
stop_group() {
  local i
  [ -n "${watcher:-}" ] || return 0
  kill -- "-$watcher" 2>/dev/null || true
  for i in $(seq 50); do
    if ! pgrep -g "$watcher" >/dev/null; then
      watcher=""
      return 0
    fi
    sleep 0.1
  done
  printf 'These processes of the background group %s outlived the test:\n' "$watcher" >&2
  pgrep -a -g "$watcher" >&2
  return 1
}
