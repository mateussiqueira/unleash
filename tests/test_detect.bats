#!/usr/bin/env bats
# Tests for detect.sh - run with: bats tests/test_detect.bats

setup() {
  load '../lib/colors.sh'
  load '../lib/detect.sh'
}

@test "is_root returns true when EUID is 0" {
  EUID=0
  run is_root
  [ "$status" -eq 0 ]
}

@test "is_root returns false when EUID is not 0" {
  EUID=501
  run is_root
  [ "$status" -eq 1 ]
}

@test "is_recovery returns false in normal environment" {
  run is_recovery
  [ "$status" -eq 1 ]
}

@test "detect_system_volume returns empty when no sys vol found" {
  run detect_system_volume "/nonexistent"
  [ -z "$output" ] || [ "$output" = "" ]
}

@test "resolve_data_volume errors on non-existent device" {
  run resolve_data_volume 2>/dev/null || true
  [ "$status" -ne 0 ]
}
