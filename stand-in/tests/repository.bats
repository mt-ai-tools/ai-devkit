bats_require_minimum_version 1.5.0

# Behavior tests for where a repository's work stands: clean once it holds
# nothing uncommitted and its upstream holds every commit; uncommitted for an
# edit or a file git does not track; unpushed for a commit its upstream lacks;
# and refused, never read as clean, where git cannot read it, the branch has
# no upstream, or the path leaves the project. Real repositories, pushing to
# a bare one beside them.

setup() {
  . "$BATS_TEST_DIRNAME/../lib/repository.sh"
  root="$BATS_TEST_TMPDIR/project"
  remote="$BATS_TEST_TMPDIR/remote.git"
  module="$root/monoframe/mf-users"
  git init -q --bare "$remote"
  mkdir -p "$module"
  git -C "$module" init -q -b main
  printf 'users\n' >"$module/users.ts"
  commit_all "$module" ground
  git -C "$module" remote add origin "$remote"
  git -C "$module" push -q -u origin main
}

# Every file of the repository at the folder given, committed.
commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.name=suite -c user.email=suite@example.invalid commit -qm "$2"
}

state() {
  run --separate-stderr get_repository_state "$root" monoframe/mf-users
}

@test "a repository holding nothing uncommitted and nothing unpushed is clean, asked from any folder inside it" {
  state
  [ "$status" -eq 0 ]
  [ "$output" = clean ]
  mkdir -p "$module/src"
  run get_repository_state "$root" monoframe/mf-users/src
  [ "$output" = clean ]
}

@test "an edit, or a file git does not track, is uncommitted" {
  printf 'edit\n' >>"$module/users.ts"
  state
  [ "$status" -eq 0 ]
  [ "$output" = uncommitted ]
  git -C "$module" checkout -q -- users.ts
  printf 'new\n' >"$module/new.ts"
  state
  [ "$output" = uncommitted ]
}

@test "a commit its upstream does not hold is unpushed, and pushing it makes it clean" {
  printf 'edit\n' >>"$module/users.ts"
  commit_all "$module" edit
  state
  [ "$status" -eq 0 ]
  [ "$output" = unpushed ]
  git -C "$module" push -q
  state
  [ "$output" = clean ]
}

@test "uncommitted is named before unpushed where both hold" {
  printf 'edit\n' >>"$module/users.ts"
  commit_all "$module" edit
  printf 'more\n' >>"$module/users.ts"
  state
  [ "$output" = uncommitted ]
}

@test "a branch with no upstream, or a checkout on no branch, is refused, never read as clean" {
  git -C "$module" branch -q --unset-upstream
  state
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_repository_no_upstream_note monoframe/mf-users)" ]
  git -C "$module" branch -q -u origin/main
  git -C "$module" checkout -q --detach
  state
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_repository_no_upstream_note monoframe/mf-users)" ]
}

@test "a folder git cannot read is refused, never read as clean" {
  mkdir -p "$BATS_TEST_TMPDIR/plain/no-repo"
  run --separate-stderr get_repository_state "$BATS_TEST_TMPDIR/plain" no-repo
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_repository_unreadable_note no-repo)" ]
}

@test "a path that leaves the project, or is no folder, is refused" {
  for path in /etc ../remote.git monoframe/../../remote.git "" monoframe/mf-media; do
    run --separate-stderr get_repository_state "$root" "$path"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_repository_missing_note "$path")" ]
  done
}
