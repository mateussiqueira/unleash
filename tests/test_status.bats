#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/status.sh'
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/private/etc"
  mkdir -p "$TEST_DIR/private/var/db/ConfigurationProfiles/Settings"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "check_mdm_status exits cleanly" {
  run check_mdm_status "$TEST_DIR" 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "deep_status exits cleanly" {
  run deep_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "deep_status_json contains braces" {
  run deep_status_json 2>/dev/null || true
  echo "$output" | grep -q "}"
}

@test "deep_status_json counts a single matching process without subtracting it" {
  profiles() {
    if [ "$1" = -C ]; then echo '<key>ProfileDisplayName</key>';
    else echo 'MDM enrollment: No'; fi
  }
  sudo() { "$@"; }
  pgrep() { echo '42 mdmclient'; }
  ps() { echo 'test 42 0.0 0.0 1 1 ? S 00:00 0:00 mdmclient'; }
  run deep_status_json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; assert json.load(sys.stdin)["running_mdm_processes"] == 1'
}
