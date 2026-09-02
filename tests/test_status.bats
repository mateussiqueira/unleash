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

@test "deep_status handles zero profiles under nounset" {
  local mock_bin="$TEST_DIR/bin"
  mkdir -p "$mock_bin"

  printf '#!/bin/bash\nexit 0\n' > "$mock_bin/profiles"
  printf '#!/bin/bash\nexec "$@"\n' > "$mock_bin/sudo"
  chmod +x "$mock_bin/profiles" "$mock_bin/sudo"

  run env PATH="$mock_bin:$PATH" bash -u -c '
    source "$1/lib/colors.sh"
    source "$1/lib/status.sh"
    pf_status() { :; }
    deep_status
  ' bash "$BATS_TEST_DIRNAME/.."

  [ "$status" -eq 0 ]
  [[ "$output" != *"integer expression expected"* ]]
}
