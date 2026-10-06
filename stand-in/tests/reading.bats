bats_require_minimum_version 1.5.0

# Behavior tests for the cold reading's settings: every tool it may use is
# denied the stand-in's working folder, and a folder that cannot be named as
# an absolute path is refused rather than left reachable. Pure, so no model
# is asked here.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/reading.sh"
}

@test "each of the reading's tools is denied the stand-in's folder, by its absolute path" {
  run to_reading_settings /srv/project/aidk-stand-in
  [ "$status" -eq 0 ]
  [ "$output" = '{"permissions":{"deny":["Read(//srv/project/aidk-stand-in/**)","Grep(//srv/project/aidk-stand-in/**)","Glob(//srv/project/aidk-stand-in/**)"]}}' ]
}

@test "a folder that is not absolute is refused" {
  run --separate-stderr to_reading_settings aidk-stand-in
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_folder_not_absolute_note aidk-stand-in)" ]
}
