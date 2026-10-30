#!/usr/bin/env bats

@test "admin rejects normal mode before resolving a target volume" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    run bash -u -c '
      source <(sed '\''/^main "\$@"$/d'\'' "$1")
      is_recovery() { return 1; }
      resolve_data_volume() { echo TARGET_WAS_ACCESSED; }
      admin_only_mode() { echo ADMIN_FLOW_WAS_STARTED; }
      cmd_admin
    ' "$script" "$script"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Admin creation must run from Recovery mode"* ]]
    [[ "$output" != *"TARGET_WAS_ACCESSED"* ]]
    [[ "$output" != *"ADMIN_FLOW_WAS_STARTED"* ]]
  done
}

@test "admin dry run returns before accessing account or enrollment state" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    run bash -u -c '
      source <(sed '\''/^main "\$@"$/d'\'' "$1")
      DRY_RUN=true
      dscl_node() { echo ACCOUNT_STATE_WAS_ACCESSED; return 1; }
      admin_only_mode "/mock/Data volume"
    ' "$script" "$script"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN] Would create a local admin user"* ]]
    [[ "$output" != *"ACCOUNT_STATE_WAS_ACCESSED"* ]]
  done
}
