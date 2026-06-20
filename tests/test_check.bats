#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/check.sh'
}

@test "run_preformat_check exits cleanly" {
  run run_preformat_check 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "check_upgrade_safety exits cleanly" {
  run check_upgrade_safety 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "run_preformat_check contains SAFE or MDM" {
  run run_preformat_check 2>/dev/null || true
  echo "$output" | grep -qiE "safe|mdm"
}
