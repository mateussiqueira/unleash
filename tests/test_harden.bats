#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/harden.sh'
}

@test "harden_live_os exits cleanly" {
  run harden_live_os 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "harden_status exits cleanly" {
  run harden_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}
