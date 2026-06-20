#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/history.sh'
}

@test "show_history exits cleanly with no logs" {
  run show_history 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "clear_history does not error with no logs" {
  run clear_history 2>/dev/null || true
  [ "$status" -eq 0 ]
}
