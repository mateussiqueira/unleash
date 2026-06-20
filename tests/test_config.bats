#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/config.sh'
  CONFIG_FILE=$(mktemp)
}

teardown() {
  rm -f "$CONFIG_FILE"
}

@test "load_config handles missing file" {
  CONFIG_FILE="/nonexistent/config"
  run load_config
  [ "$status" -eq 0 ]
}

@test "save_config writes key=value" {
  save_config "WEBHOOK" "https://example.com" 2>/dev/null || true
  run grep "WEBHOOK=https://example.com" "$CONFIG_FILE"
  [ "$status" -eq 0 ]
}

@test "load_config reads saved values" {
  save_config "LOG_LEVEL" "verbose" 2>/dev/null || true
  VERBOSE=false
  load_config
  [ "$VERBOSE" = true ]
}

@test "save_config updates existing key" {
  save_config "KEY" "old" 2>/dev/null || true
  save_config "KEY" "new" 2>/dev/null || true
  run grep -c "KEY=new" "$CONFIG_FILE"
  [ "$output" -eq 1 ]
}
