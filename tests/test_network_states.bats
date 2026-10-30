#!/usr/bin/env bats

run_network_state() {
  local script="$1" mode="$2"
  local definitions="$BATS_TEST_TMPDIR/network.functions"
  sed '/^main "\$@"$/d' "$script" > "$definitions"
  run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
    source "$1"
    mode="$2"
    load_config() { :; }
    sw_vers() { echo fixture; }
    command() {
      if [ "$mode" = missing ] && [ "$*" = "-v networksetup" ]; then return 1; fi
      builtin command "$@"
    }
    networksetup() {
      case "$*" in
        -listallhardwareports)
          case "$mode" in portsfail|missing) echo PRIVATE-DATA >&2; return 1 ;; esac
          printf "Hardware Port: Ethernet\nDevice: en0\n"
          [ "$mode" != absent ] || return 0
          printf "Hardware Port: Wi-Fi\nDevice: en7\nEthernet Address: PRIVATE-MAC\n" ;;
        "-getairportpower en7")
          [ "$mode" != powerfail ] || { echo PRIVATE-DATA >&2; return 1; }
          echo "Wi-Fi Power (en7): On" ;;
        *) return 97 ;;
      esac
    }
    ifconfig() {
      [ "$*" = en7 ] || return 97
      [ "$mode" != linkfail ] || { echo PRIVATE-DATA >&2; return 1; }
      printf "en7: flags\n ether PRIVATE-MAC\n status: active\n"
      case "$mode" in
        configured) printf " inet 192.0.2.7 netmask 0xffffff00\n" ;;
        linklocal) printf " inet 169.254.8.9 netmask 0xffff0000\n" ;;
      esac
    }
    main doctor --network
  ' "$script" "$definitions" "$mode"
}

@test "network doctor distinguishes query failure from absent hardware" {
  local entrypoint mode
  for entrypoint in unleash unleash-standalone.sh; do
    for mode in missing portsfail powerfail linkfail; do
      run_network_state "$BATS_TEST_DIRNAME/../$entrypoint" "$mode"
      [ "$status" -ne 0 ]
      [[ "$output" != *"No Wi-Fi hardware port"* ]]
      [[ "$output" != *"PRIVATE-"* ]]
    done
  done
}

@test "network doctor classifies IPv4 state without exposing addresses" {
  local entrypoint mode expected
  for entrypoint in unleash unleash-standalone.sh; do
    for mode in configured linklocal none; do
      expected="$mode"; [ "$mode" != linklocal ] || expected=link-local
      run_network_state "$BATS_TEST_DIRNAME/../$entrypoint" "$mode"
      [ "$status" -eq 0 ]
      [[ "$output" == *"Wi-Fi IPv4: $expected"* ]]
      [[ "$output" != *"192.0.2.7"* ]]
      [[ "$output" != *"169.254.8.9"* ]]
      [[ "$output" != *"PRIVATE-"* ]]
    done
  done
}

@test "network doctor reports absent Wi-Fi after a successful hardware query" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    run_network_state "$BATS_TEST_DIRNAME/../$entrypoint" absent
    [ "$status" -eq 0 ]
    [[ "$output" == *"No Wi-Fi hardware port reported"* ]]
  done
}
