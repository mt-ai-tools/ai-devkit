bats_require_minimum_version 1.5.0

# Behavior tests for reading uncommitted changes: a path holding edits or
# files git does not track is named, a clean or ignored one is not, each is
# asked of the repository holding it, and a path git cannot read is refused
# rather than read as clean.

setup() {
  . "$BATS_TEST_DIRNAME/../lib/changes.sh"
  root="$BATS_TEST_TMPDIR/project"
  mkdir -p "$root/src" "$root/module/src"
  printf 'a\n' >"$root/src/a.ts"
  printf 'ignored\n' >"$root/.gitignore"
  commit_all "$root"
  # A module that is a repository of its own inside the project.
  printf 'm\n' >"$root/module/src/m.ts"
  git -C "$root/module" init -q
  commit_all "$root/module"
}

# Every file of the repository at the folder given, committed.
commit_all() {
  [ -d "$1/.git" ] || git -C "$1" init -q
  git -C "$1" add -A
  git -C "$1" -c user.name=suite -c user.email=suite@example.invalid commit -qm ground
}

@test "a clean path, an ignored one, and one not yet written are named by none" {
  printf 'x\n' >"$root/ignored"
  run list_uncommitted_paths "$root" src/a.ts src ignored src/not-yet.ts module/src/m.ts
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an edited file, an untracked one, and a folder holding either are named, in the order given" {
  printf 'b\n' >>"$root/src/a.ts"
  printf 'n\n' >"$root/src/new.ts"
  run list_uncommitted_paths "$root" src/new.ts module/src/m.ts src src/a.ts
  [ "$status" -eq 0 ]
  [ "$output" = $'src/new.ts\nsrc\nsrc/a.ts' ]
}

@test "a path inside a repository of its own is asked of that repository" {
  printf 'edit\n' >>"$root/module/src/m.ts"
  run list_uncommitted_paths "$root" module/src/m.ts src/a.ts
  [ "$status" -eq 0 ]
  [ "$output" = "module/src/m.ts" ]
}

@test "a path git cannot read is refused, never read as clean" {
  outside="$BATS_TEST_TMPDIR/no-repo"
  mkdir -p "$outside/src"
  run --separate-stderr list_uncommitted_paths "$outside" src/a.ts
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_changes_unknown_note src/a.ts)" ]
}
