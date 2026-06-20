#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/uninstall.sh'
}

@test "do_uninstall requires root" {
  EUID=501
  run do_uninstall 2>/dev/null || true
  [ "$status" -ne 0 ]
}
