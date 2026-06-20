#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/detect.sh'
  load '../lib/doctor.sh'
}

@test "run_doctor exits cleanly" {
  run run_doctor 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "run_doctor detects missing libs" {
  local old_dir="$LIB_DIR"
  LIB_DIR="/nonexistent"
  run run_doctor 2>/dev/null || true
  LIB_DIR="$old_dir"
  echo "$output" | grep -qi "missing\|error"
}
