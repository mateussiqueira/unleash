#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/harden.sh'
}

@test "harden_live_os exits cleanly" {
  mkdir -p "$BATS_TEST_TMPDIR/Users/test/Library/LaunchAgents"
  local agents="$BATS_TEST_TMPDIR/Users/test/Library/LaunchAgents"
  echo mdm > "$agents/enrollment.plist"
  echo normal > "$agents/normal.plist"
  run harden_live_os "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  [ ! -f "$agents/enrollment.plist" ]
  [ -f "$agents/normal.plist" ]
}

@test "harden_status exits cleanly" {
  run harden_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}
