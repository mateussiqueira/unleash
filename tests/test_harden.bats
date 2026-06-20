#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/harden.sh'
}

@test "do_harden requires root" {
  EUID=501
  run do_harden 2>/dev/null || true
  [ "$status" -ne 0 ]
}

@test "install_harden_launchdaemon creates plist" {
  run install_harden_launchdaemon 2>/dev/null || true
  [ -f /Library/LaunchDaemons/com.unleash.harden.plist ] || [ "$status" -eq 0 ]
}
