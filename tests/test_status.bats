#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/status.sh'
}

@test "show_status exits cleanly" {
  run show_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "show_status_detailed exits cleanly" {
  run show_status_detailed 2>/dev/null || true
  [ "$status" -eq 0 ]
}
