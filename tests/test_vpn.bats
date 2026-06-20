#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/vpn.sh'
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/etc/pf.anchors/com.unleash"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "vpn_kill_install requires root" {
  function is_root() { false; }
  run vpn_kill_install 2>/dev/null || true
  [ "$status" -ne 0 ]
}

@test "vpn_kill_remove exits cleanly when not installed" {
  run vpn_kill_remove 2>/dev/null || true
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "vpn_kill_status exits cleanly" {
  run vpn_kill_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}
