#!/usr/bin/env bats

check_volume_output() {
  local mode="$1" entrypoint
  bats_require_minimum_version 1.5.0
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local target="$BATS_TEST_TMPDIR/$entrypoint/Data volume"
    mkdir -p "$target/private/var/db/dslocal/nodes/Default"
    run --separate-stderr bash -u -c '
      source <(sed '\''/^main "\$@"$/d'\'' "$1")
      target="$2"; mode="$3"; mounted="$4"
      diskutil() {
        case "$*" in
          "apfs list") echo "+-- Volume disk5s1 (Data)" ;;
          "info /dev/disk5s1")
            if [ -f "$mounted" ]; then printf "Mount Point: %s\n" "$target";
            else echo "Mount Point: Not mounted"; fi ;;
          "mount /dev/disk5s1")
            echo "Mount attempt diagnostic"
            [ "$mode" != locked ] || return 1
            touch "$mounted" ;;
          "apfs unlockVolume /dev/disk5s1")
            echo "Unlocking any cryptographic user"
            echo "Unlocked and mounted APFS Volume"
            touch "$mounted" ;;
          *) return 1 ;;
        esac
      }
      resolve_data_volume
    ' "$script" "$script" "$target" "$mode" "$BATS_TEST_TMPDIR/$entrypoint.mounted"
    [ "$status" -eq 0 ]
    [ "$output" = "$target" ]
    [[ "$stderr" == *"Mount attempt diagnostic"* ]]
    if [ "$mode" = locked ]; then
      [[ "$stderr" == *"Unlocked and mounted APFS Volume"* ]]
    fi
  done
}

@test "mount diagnostics stay out of the selected Data volume path" {
  check_volume_output unmounted
}

@test "FileVault unlock diagnostics stay out of the selected Data volume path" {
  check_volume_output locked
}
