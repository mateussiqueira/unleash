#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/vpn.sh'
  TEST_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "vpn_kill_install requires root" {
  EUID=501
  run vpn_kill_install 2>/dev/null || true
  [ "$status" -ne 0 ]
}

@test "vpn_kill_remove exits cleanly when not installed" {
  run vpn_kill_remove 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "vpn_kill_status exits cleanly" {
  run vpn_kill_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "vpn_kill_remove cleans pf.conf" {
  mkdir -p "$TEST_DIR/etc"
  echo '# Added by unleash — VPN kill-switch' > "$TEST_DIR/etc/pf.conf"
  echo 'anchor "com.unleash/vpn-kill"' >> "$TEST_DIR/etc/pf.conf"
  VPN_RULES_FILE="$TEST_DIR/etc/pf.anchors/com.unleash/vpn-kill"
  mkdir -p "$(dirname "$VPN_RULES_FILE")"
  touch "$VPN_RULES_FILE"

  PF_CONF="$TEST_DIR/etc/pf.conf"
  run vpn_kill_remove 2>/dev/null || true
  [ ! -f "$VPN_RULES_FILE" ]
}
