#!/usr/bin/env bats
# Tests for dscl.sh - run with: bats tests/test_dscl.bats

setup() {
  load '../lib/colors.sh'
  load '../lib/dscl.sh'
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/private/var/db/dslocal/nodes/Default"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "dscl_node returns correct path" {
  run dscl_node "$TEST_DIR"
  [ "$output" = "$TEST_DIR/private/var/db/dslocal/nodes/Default" ]
}

@test "find_available_uid returns 501 for empty node" {
  local node
  node=$(dscl_node "$TEST_DIR")
  run find_available_uid "$node"
  [ "$output" = "501" ]
}
