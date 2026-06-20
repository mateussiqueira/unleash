#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/monitor.sh'
  TEST_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "monitor_status exits cleanly when not running" {
  run monitor_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "stop_monitor exits cleanly when not running" {
  run stop_monitor 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "install_monitor_launchdaemon creates plist file" {
  SCRIPT_DIR="$TEST_DIR"
  mkdir -p "$TEST_DIR"
  run install_monitor_launchdaemon "$TEST_DIR" 2>/dev/null || true
  [ -f "$TEST_DIR/Library/LaunchDaemons/com.unleash.monitor.plist" ]
}

@test "install_monitor_launchdaemon plist is valid xml" {
  SCRIPT_DIR="$TEST_DIR"
  mkdir -p "$TEST_DIR"
  run install_monitor_launchdaemon "$TEST_DIR" 2>/dev/null || true
  run grep -c "plist" "$TEST_DIR/Library/LaunchDaemons/com.unleash.monitor.plist"
  [ "$output" -gt 0 ]
}

@test "install_monitor_launchdaemon references unleash binary" {
  SCRIPT_DIR="$TEST_DIR"
  mkdir -p "$TEST_DIR"
  run install_monitor_launchdaemon "$TEST_DIR" 2>/dev/null || true
  run grep -c "unleash" "$TEST_DIR/Library/LaunchDaemons/com.unleash.monitor.plist"
  [ "$output" -gt 0 ]
}

@test "uninstall_monitor_launchdaemon removes plist" {
  mkdir -p "$TEST_DIR/Library/LaunchDaemons"
  touch "$TEST_DIR/Library/LaunchDaemons/com.unleash.monitor.plist"
  run uninstall_monitor_launchdaemon "$TEST_DIR" 2>/dev/null || true
  [ ! -f "$TEST_DIR/Library/LaunchDaemons/com.unleash.monitor.plist" ]
}

@test "monitor_mdm requires root" {
  function is_root() { false; }
  run monitor_mdm 2>/dev/null || true
  [ "$status" -ne 0 ]
}
