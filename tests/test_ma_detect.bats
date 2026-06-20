#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/ma_detect.sh'
}

@test "detect_migration_assistant exits cleanly" {
  run detect_migration_assistant 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "clean_ma_artifacts does not error without users" {
  run clean_ma_artifacts 2>/dev/null || true
  [ "$status" -eq 0 ]
}
