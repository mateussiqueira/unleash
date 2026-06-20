#!/usr/bin/env bats
# Tests for firewall.sh - run with: bats tests/test_firewall.bats

setup() {
  load '../lib/colors.sh'
  load '../lib/firewall.sh'
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/etc/pf.anchors/com.unleash"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "install_pf_mdm_block creates anchor file" {
  FIREWALL_ANCHOR_DIR="/etc/pf.anchors"
  install_pf_mdm_block "$TEST_DIR" 2>/dev/null || true
  [ -f "$TEST_DIR/etc/pf.anchors/com.unleash/mdm" ]
}

@test "install_pf_mdm_block contains Apple IP ranges" {
  install_pf_mdm_block "$TEST_DIR" 2>/dev/null || true
  run grep -c "17.0.0.0/8" "$TEST_DIR/etc/pf.anchors/com.unleash/mdm"
  [ "$output" -gt 0 ]
}

@test "install_pf_mdm_block updates pf.conf" {
  install_pf_mdm_block "$TEST_DIR" 2>/dev/null || true
  run grep -c "com.unleash" "$TEST_DIR/etc/pf.conf"
  [ "$output" -gt 0 ]
}

@test "remove_pf_mdm_block removes anchor and pf.conf entries" {
  install_pf_mdm_block "$TEST_DIR" 2>/dev/null || true
  remove_pf_mdm_block "$TEST_DIR" 2>/dev/null || true
  [ ! -f "$TEST_DIR/etc/pf.anchors/com.unleash/mdm" ]
  run grep -c "com.unleash" "$TEST_DIR/etc/pf.conf" 2>/dev/null || echo "0"
  [ "$output" = "0" ]
}
