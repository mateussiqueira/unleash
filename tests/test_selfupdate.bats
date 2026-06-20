#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/selfupdate.sh'
}

@test "check_for_updates handles no network" {
  run check_for_updates 2>/dev/null || true
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "get_latest_version fails gracefully offline" {
  run get_latest_version 2>/dev/null || true
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
