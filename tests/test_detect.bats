#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/detect.sh'
}

@test "is_root reports whether the effective user is root" {
  local expected=1
  [ "$EUID" -ne 0 ] || expected=0
  run is_root
  [ "$status" -eq "$expected" ]
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
  read() { echo PROMPT_WAS_REACHED; return 1; }
  run resolve_data_volume </dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot select a Data volume without a terminal"* ]]
  [[ "$output" != *"PROMPT_WAS_REACHED"* ]]
}
