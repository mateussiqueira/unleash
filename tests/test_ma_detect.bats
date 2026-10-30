#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/ma_detect.sh'
  mkdir -p "$BATS_TEST_TMPDIR/Users"
}

@test "detect_migration_assistant exits cleanly" {
  run detect_migration_assistant "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
}

@test "clean_ma_artifacts does not error without users" {
  run clean_ma_artifacts "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
}

@test "migration audit detects enrollment and MDM cache directories" {
  local caches="$BATS_TEST_TMPDIR/Users/test/Library/Caches"
  mkdir -p "$caches/com.apple.enrollmenttool" "$caches/com.apple.mdm"
  echo cached > "$caches/com.apple.enrollmenttool/record"
  echo cached > "$caches/com.apple.mdm/record"
  run detect_migration_assistant "$BATS_TEST_TMPDIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"enrollment cache files"* ]]
  [[ "$output" == *"MDM cache files"* ]]
}
