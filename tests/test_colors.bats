#!/usr/bin/env bats
# Tests for colors.sh - run with: bats tests/test_colors.bats

setup() {
  load '../lib/colors.sh'
  TEST_LOG=$(mktemp)
}

teardown() {
  rm -f "$TEST_LOG"
}

@test "log writes to LOG_FILE when set" {
  LOG_FILE="$TEST_LOG"
  log "INFO" "test message"
  run grep "test message" "$TEST_LOG"
  [ "$status" -eq 0 ]
}

@test "log respects VERBOSE for DEBUG" {
  VERBOSE=false
  run log "DEBUG" "hidden message"
  [ -z "$output" ]
}

@test "log shows DEBUG when VERBOSE is true" {
  VERBOSE=true
  run log "DEBUG" "visible message"
  echo "$output" | grep -q "visible"
}

@test "error_exit exits with non-zero" {
  run error_exit "test error" 2>/dev/null
  [ "$status" -ne 0 ]
}

@test "header outputs formatted title" {
  run header "Test Title"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Test Title"
}
