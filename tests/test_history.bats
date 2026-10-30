#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/history.sh'
}

@test "show_history exits cleanly with no logs" {
  run show_history "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
}

@test "clear_history does not error with no logs" {
  echo event > "$BATS_TEST_TMPDIR/unleash-monitor.log"
  run clear_history "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  [ ! -s "$BATS_TEST_TMPDIR/unleash-monitor.log" ]
}
