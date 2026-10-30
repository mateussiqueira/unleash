#!/usr/bin/env bats

@test "dualboot dry run returns before target access with or without root" {
  local entrypoint root_status
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local definitions="$BATS_TEST_TMPDIR/$entrypoint.functions"
    sed '/^main "\$@"$/d' "$script" > "$definitions"
    for root_status in 0 1; do
      run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
        source "$1"
        root_status="$2"
        load_config() { :; }
        is_root() { return "$root_status"; }
        resolve_target_volumes() { echo TARGET_WAS_ACCESSED; return 97; }
        create_admin_user() { echo USER_WAS_WRITTEN; return 97; }
        main --dry-run dualboot
      ' "$script" "$definitions" "$root_status"
      [ "$status" -eq 0 ]
      [[ "$output" == *"[DRY RUN] Would select an external macOS installation"* ]]
      [[ "$output" != *"TARGET_WAS_ACCESSED"* ]]
      [[ "$output" != *"USER_WAS_WRITTEN"* ]]
    done
  done
}
