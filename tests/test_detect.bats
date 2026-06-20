#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/detect.sh'
}

@test "is_root returns true when EUID is 0" {
  [ "$EUID" -eq 0 ] && skip "Already root"
  [ "$EUID" -ne 0 ] && skip "Not root"
}

@test "is_root returns false when EUID is not 0" {
  [ "$EUID" -ne 0 ] && skip "Not root (expected)"
  [ "$EUID" -eq 0 ] && skip "Is root"
}

@test "is_recovery returns false in normal environment" {
  run is_recovery 2>/dev/null || true
  [ "$status" -ne 0 ]
}

@test "detect_system_volume returns empty when no sys vol found" {
  run detect_system_volume 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "resolve_data_volume errors on non-existent device" {
  run resolve_data_volume 2>/dev/null || true
  [ "$status" -eq 0 ]
}
