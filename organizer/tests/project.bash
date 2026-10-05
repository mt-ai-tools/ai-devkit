# A throwaway project for the organizer's suites: a briefs folder, a clock
# pinned to one moment, and helpers that write briefs and marks. Loaded by the
# suites, never run alone.

# Every suite runs against a project of its own, never the one the suite is
# run from, and from a folder that is not the project root, so a path read
# from the working directory instead of the root shows up as a failure.
setup_project() {
  script="$BATS_TEST_DIRNAME/../bin/organizer.sh"
  lib="$BATS_TEST_DIRNAME/../lib"
  . "$lib/words.sh"
  project="$BATS_TEST_TMPDIR/project"
  plans="$project/aidk-plans"
  marks="$project/aidk-organizer/taken"
  mkdir -p "$plans" "$BATS_TEST_TMPDIR/elsewhere"
  export CLAUDE_PROJECT_DIR="$project"
  cd "$BATS_TEST_TMPDIR/elsewhere"
  # The organizer asks the clock through `date` alone, so a `date` of the
  # suite's own, first on the path of the organizer only, pins every age and
  # every since. Not on the suite's own path: bats times its tests with `date`.
  fakebin="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$fakebin"
  now="2026-10-04T21:30:00Z"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\n' "$now" >"$fakebin/date"
  chmod +x "$fakebin/date"
}

# The organizer, run with the pinned clock.
organizer() {
  PATH="$fakebin:$PATH" "$script" "$@"
}

# A brief in the briefs folder: name, summary, after, touches, creates, each
# list written as the header holds it.
brief() {
  printf -- '---\nsummary: %s\nafter: %s\ntouches: %s\ncreates: %s\n---\n\n# %s\n\nBody.\n' \
    "$2" "$3" "$4" "$5" "$1" >"$plans/$1.md"
}

# A mark: brief, session, since.
mark() {
  mkdir -p "$marks"
  printf 'session: %s\nsince: %s\n' "$2" "$3" >"$marks/$1"
}

# A folder under the project root, for touches and creates to name.
place() {
  mkdir -p "$project/$1"
}
