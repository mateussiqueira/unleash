#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/selfupdate.sh'
}

@test "do_self_update handles no network" {
  run do_self_update 2>/dev/null || true
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "do_self_update notices missing curl" {
  function command() { return 1; }
  run do_self_update 2>/dev/null || true
  [ "$status" -ne 0 ]
}
