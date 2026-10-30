#!/usr/bin/env bats
# Tests for colors.sh - run with: bats tests/test_colors.bats

setup() {
  bats_require_minimum_version 1.5.0
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

@test "header draws a valid Unicode border for the title width" {
  run header Mac
  [ "$status" -eq 0 ]
  [[ "$output" == *"╔═══════╗"* ]]
  [[ "$output" == *"╚═══════╝"* ]]
}

@test "diagnostics use stderr without contaminating helper return values" {
  local source_file
  for source_file in lib/colors.sh unleash-standalone.sh; do
    run --separate-stderr bash -u -c '
      source <(sed "/^error_exit()/,\$d" "$1")
      volume_path() {
        log INFO "Locating Data volume"
        log OK "Data volume found"
        printf "%s\n" "/Volumes/Work Data"
      }
      result=$(volume_path)
      printf "%s\n" "$result"
    ' bash "$BATS_TEST_DIRNAME/../$source_file"

    [ "$status" -eq 0 ]
    [ "$output" = "/Volumes/Work Data" ]
    [[ "$stderr" == *"Locating Data volume"* ]]
    [[ "$stderr" == *"Data volume found"* ]]
  done
}

@test "diagnostics still reach the log file when stdout is captured" {
  LOG_FILE="$TEST_LOG"
  local result
  result=$(log WARN "Review the selected volume" 2>/dev/null)

  [ -z "$result" ]
  grep -q 'Review the selected volume' "$TEST_LOG"
}
