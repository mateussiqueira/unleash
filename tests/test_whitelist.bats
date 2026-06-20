#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/whitelist.sh'
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/etc/pf.anchors"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "install_selective_block creates anchor" {
  run install_selective_block "$TEST_DIR" 2>/dev/null || true
  [ -f "$TEST_DIR/etc/pf.anchors/com.unleash.selective" ]
}

@test "install_selective_block contains MDM domains" {
  run install_selective_block "$TEST_DIR" 2>/dev/null || true
  run grep -c "mdmenrollment" "$TEST_DIR/etc/pf.anchors/com.unleash.selective"
  [ "$output" -gt 0 ]
}
