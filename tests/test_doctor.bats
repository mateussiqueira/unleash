#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/detect.sh'
  load '../lib/doctor.sh'
}

@test "run_doctor exits cleanly" {
  run run_doctor 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "run_doctor detects missing libs" {
  local old_dir="$LIB_DIR"
  LIB_DIR="/nonexistent"
  run run_doctor 2>/dev/null || true
  LIB_DIR="$old_dir"
  echo "$output" | grep -qi "missing\|error"
}

@test "network doctor reports build power and link using only read commands" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local definitions="$BATS_TEST_TMPDIR/$entrypoint.functions"
    local calls="$BATS_TEST_TMPDIR/$entrypoint.calls"
    sed '/^main "\$@"$/d' "$script" > "$definitions"
    run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
      source "$1"
      calls="$2"
      load_config() { :; }
      sw_vers() {
        echo "sw_vers $*" >> "$calls"
        case "$1" in -productVersion) echo 27.0 ;; -buildVersion) echo TESTBUILD ;; *) return 97 ;; esac
      }
      networksetup() {
        echo "networksetup $*" >> "$calls"
        case "$*" in
          -listallhardwareports) printf "Hardware Port: Ethernet\nDevice: en0\nHardware Port: Wi-Fi\nDevice: en7\nEthernet Address: PRIVATE-MAC\n" ;;
          "-getairportpower en7") echo "Wi-Fi Power (en7): On" ;;
          *) return 97 ;;
        esac
      }
      ifconfig() {
        echo "ifconfig $*" >> "$calls"
        [ "$*" = en7 ] || return 97
        printf "en7: flags\n ether PRIVATE-MAC\n status: inactive\n"
      }
      main doctor --network
    ' "$script" "$definitions" "$calls"
    [ "$status" -eq 0 ]
    [[ "$output" == *"27.0 (build TESTBUILD)"* ]]
    [[ "$output" == *"Wi-Fi interface: en7"* ]]
    [[ "$output" == *"Wi-Fi power: on"* ]]
    [[ "$output" == *"Link status: inactive"* ]]
    [[ "$output" != *"PRIVATE-MAC"* ]]
    run grep -vE '^(sw_vers -(productVersion|buildVersion)|networksetup -listallhardwareports|networksetup -getairportpower en7|ifconfig en7)$' "$calls"
    [ "$status" -eq 1 ]
  done
}

@test "standalone doctor verifies embedded modules without a lib directory" {
  local script="$BATS_TEST_DIRNAME/../unleash-standalone.sh"
  local definitions="$BATS_TEST_TMPDIR/standalone.functions"
  sed '/^main "\$@"$/d' "$script" > "$definitions"
  run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
    unset LIB_DIR
    source "$1"
    load_config() { :; }
    main doctor
  ' "$script" "$definitions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Embedded core modules loaded"* ]]
  [[ "$output" != *"unbound variable"* ]]
}
