#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/vpn.sh'
}

@test "install_vpn_killswitch exits cleanly" {
  run install_vpn_killswitch 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "remove_vpn_killswitch exits cleanly" {
  run remove_vpn_killswitch 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "vpn_killswitch_status exits cleanly" {
  run vpn_killswitch_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}
