#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/monitor.sh'
}

@test "monitor_status exits cleanly when not running" {
  run monitor_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "stop_monitor exits cleanly when not running" {
  run stop_monitor 2>/dev/null || true
  [ "$status" -eq 0 ]
}
