#!/usr/bin/env bats
# Tests for heal.sh - run with: bats tests/test_heal.bats

setup() {
  load '../lib/colors.sh'
  load '../lib/suppress.sh'
  load '../lib/heal.sh'
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/private/etc"
  mkdir -p "$TEST_DIR/private/var/db/ConfigurationProfiles/Settings"
  mkdir -p "$TEST_DIR/private/var/db/com.apple.xpc.launchd"
  DRY_RUN=false
  suppress_enrollment "$TEST_DIR" 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "heal detects clean system" {
  run heal_suppress "$TEST_DIR" 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "heal re-applies when DEP record reappears" {
  touch "$TEST_DIR/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
  heal_suppress "$TEST_DIR" 2>/dev/null || true
  [ ! -f "$TEST_DIR/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" ]
}

@test "heal re-applies when hosts block missing" {
  > "$TEST_DIR/private/etc/hosts"
  heal_suppress "$TEST_DIR" 2>/dev/null || true
  run grep -c "iprofiles.apple.com" "$TEST_DIR/private/etc/hosts"
  [ "$output" -gt 0 ]
}
