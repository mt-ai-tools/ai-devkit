bats_require_minimum_version 1.5.0

# Behavior tests for a session's wait: a wait on a brief is written into the
# session's own brief through the work organizer and watched until the
# organizer finishes the brief waited for, never before; a wait on a
# repository is watched until it holds nothing uncommitted and nothing
# unpushed, uncommitted alone and unpushed alone each keeping it waiting; each
# leaves the mark the gate reads, over or refused with why, and a refusal at
# any look ends the watch. The organizer is the kit's own; the repositories
# are real, pushing to a bare one beside the project.

setup() {
  script="$BATS_TEST_DIRNAME/../bin/stand-in.sh"
  organizer="$BATS_TEST_DIRNAME/../../organizer/bin/organizer.sh"
  . "$BATS_TEST_DIRNAME/../lib/wait.sh"
  project="$BATS_TEST_TMPDIR/project"
  history="$project/aidk-stand-in"
  mkdir -p "$project/aidk-plans" "$project/aidk-organizer/taken" "$BATS_TEST_TMPDIR/elsewhere"
  export CLAUDE_PROJECT_DIR="$project"
  export CLAUDE_CODE_SESSION_ID="session-1"
  cd "$BATS_TEST_TMPDIR/elsewhere"
  brief file-trash "[]"
  brief media-bucket "[]"
  printf 'session: session-1\nsince: 2026-10-07T09:00:00Z\n' >"$project/aidk-organizer/taken/file-trash"
  # A module of its own, pushed to a bare remote, as another session holds it.
  remote="$BATS_TEST_TMPDIR/remote.git"
  module="$project/monoframe/mf-users"
  git init -q --bare "$remote"
  mkdir -p "$module"
  git -C "$module" init -q -b main
  printf 'users\n' >"$module/users.ts"
  commit_all "$module" ground
  git -C "$module" remote add origin "$remote"
  git -C "$module" push -q -u origin main
  watcher=""
}

teardown() {
  [ -z "$watcher" ] || kill "$watcher" 2>/dev/null || true
  [ ! -d "$history" ] || chmod -R u+rwx "$history"
}

# A brief in the suite's project, with what it waits on.
brief() {
  printf -- '---\nsummary: The %s brief.\nafter: %s\ntouches: [aidk-plans]\ncreates: []\n---\n\n# %s\n' \
    "$1" "$2" "$1" >"$project/aidk-plans/$1.md"
}

commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.name=suite -c user.email=suite@example.invalid commit -qm "$2"
}

# The session's wait, of the kind and on what given, watched in the
# background by a shell of its own, its output kept; its process left in
# watcher. A shell of its own, never a subshell of the test's: one the suite
# stops in its teardown must stop, and leave nothing holding the suite's
# output open. Its looks a tenth of a second apart, so it is seen across
# many.
start_watch() {
  bash -c '. "$1"; WAIT_LOOK_SECONDS=0.1; run_wait "$2" session-1 "$3" "$4"' _ \
    "$BATS_TEST_DIRNAME/../lib/wait.sh" "$history" "$1" "$2" \
    >"$BATS_TEST_TMPDIR/out" 2>"$BATS_TEST_TMPDIR/err" 3>&- &
  watcher=$!
}

# True while the watch still runs after the seconds given, its mark not
# written. An organizer's answer takes most of a second, so a wait on a
# brief is given several.
still_waiting() {
  sleep "$1"
  kill -0 "$watcher" 2>/dev/null
  [ ! -e "$history/woken/session-1" ]
}

# True once the file given holds the line given, within twenty seconds.
holds_line() {
  local i
  for i in $(seq 200); do
    grep -qxF -- "$2" "$1" && return 0
    sleep 0.1
  done
  return 1
}

# The watch's status once it ends, within twenty seconds; 99 where it does
# not.
watch_status() {
  local i
  for i in $(seq 200); do
    if ! kill -0 "$watcher" 2>/dev/null; then
      wait "$watcher" && return 0
      return 1
    fi
    sleep 0.1
  done
  return 99
}

mark() { cat "$history/woken/session-1"; }

@test "a brief wait is written into the session's brief, and is over when the brief waited for is finished, not before" {
  start_watch brief media-bucket
  holds_line "$project/aidk-plans/file-trash.md" "after: [media-bucket]"
  still_waiting 4
  [ "$("$organizer" waits file-trash)" = media-bucket ]
  "$organizer" done media-bucket >/dev/null
  watch_status
  [ "$(mark)" = "$(to_woken_mark over brief media-bucket)" ]
  [ "$(cat "$BATS_TEST_TMPDIR/out")" = "$(wait_written_line; printf '%s\n' "$project/aidk-plans/file-trash.md"; wait_over_note "$(wait_brief_words media-bucket)")" ]
  [ ! -s "$BATS_TEST_TMPDIR/err" ]
  grep -qxF -- "after: []" "$project/aidk-plans/file-trash.md"
}

@test "a repository wait is over once it holds nothing uncommitted and nothing unpushed: uncommitted alone, then unpushed alone, keep it waiting" {
  printf 'edit\n' >>"$module/users.ts"
  start_watch repository monoframe/mf-users
  still_waiting 1
  commit_all "$module" edit
  still_waiting 1
  git -C "$module" push -q
  watch_status
  [ "$(mark)" = "$(to_woken_mark over repository monoframe/mf-users)" ]
  [ "$(cat "$BATS_TEST_TMPDIR/out")" = "$(wait_over_note "$(wait_repository_words monoframe/mf-users)")" ]
}

@test "a refusal at a later look ends the watch: the brief waited for gone by hand is never read as finished" {
  start_watch brief media-bucket
  holds_line "$project/aidk-plans/file-trash.md" "after: [media-bucket]"
  still_waiting 2
  rm "$project/aidk-plans/media-bucket.md"
  status=0
  watch_status || status=$?
  [ "$status" -eq 1 ]
  why="$(. "$BATS_TEST_DIRNAME/../../organizer/lib/words.sh"; refuse_awaited_missing_note file-trash media-bucket)"
  [ "$(mark)" = "$(to_woken_mark refused brief media-bucket "$why")" ]
  [ "$(cat "$BATS_TEST_TMPDIR/err")" = "$why" ]
}

@test "the entry's wait already over ends at once, says so, and leaves the over mark" {
  run --separate-stderr timeout 20 "$script" wait-repository monoframe/mf-users
  [ "$status" -eq 0 ]
  [ "$output" = "$(wait_over_note "$(wait_repository_words monoframe/mf-users)")" ]
  [ "$(mark)" = "$(to_woken_mark over repository monoframe/mf-users)" ]
}

@test "a repository with no upstream is refused, never read as over: the refused mark holds why" {
  git -C "$module" branch -q --unset-upstream
  run --separate-stderr timeout 20 "$script" wait-repository monoframe/mf-users
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_repository_no_upstream_note monoframe/mf-users)" ]
  [ "$(mark)" = "$(to_woken_mark refused repository monoframe/mf-users "$stderr")" ]
}

@test "a brief wait in a session holding no brief, or on one the organizer does not know, is refused, and nothing is written" {
  rm "$project/aidk-organizer/taken/file-trash"
  cp -r "$project/aidk-plans" "$BATS_TEST_TMPDIR/plans-before"
  run --separate-stderr timeout 20 "$script" wait-brief media-bucket
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_wait_no_brief_note)" ]
  [ "$(mark)" = "$(to_woken_mark refused brief media-bucket "$stderr")" ]
  printf 'session: session-1\nsince: 2026-10-07T09:00:00Z\n' >"$project/aidk-organizer/taken/file-trash"
  run --separate-stderr timeout 20 "$script" wait-brief no-such-brief
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(. "$BATS_TEST_DIRNAME/../../organizer/lib/words.sh"; refuse_no_brief_note no-such-brief)" ]
  [ "$(mark)" = "$(to_woken_mark refused brief no-such-brief "$stderr")" ]
  diff -r "$project/aidk-plans" "$BATS_TEST_TMPDIR/plans-before"
}

@test "with no session id in the environment the wait is refused, and no mark is left" {
  for id in "" "../on/session-1"; do
    CLAUDE_CODE_SESSION_ID="$id" run --separate-stderr timeout 20 "$script" wait-repository monoframe/mf-users
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_wait_session_note CLAUDE_CODE_SESSION_ID)" ]
  done
  unset CLAUDE_CODE_SESSION_ID
  run --separate-stderr timeout 20 "$script" wait-repository monoframe/mf-users
  [ "$status" -eq 1 ]
  [ ! -e "$history/woken" ]
}

@test "a mark that cannot be written is refused, and the wait is not said to be over" {
  mkdir -p "$history/woken"
  chmod a-w "$history/woken"
  run --separate-stderr timeout 20 "$script" wait-repository monoframe/mf-users
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_woken_unwritable_note "$history/woken")" ]
  [ -z "$(ls -A "$history/woken")" ]
}
