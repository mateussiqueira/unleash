#!/usr/bin/env bats

run_preview() {
  local script="$1" command="$2" recovery="$3"
  local definitions="$BATS_TEST_TMPDIR/preview.functions"
  sed '/^main "\$@"$/d' "$script" > "$definitions"
  run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
    source "$1"
    action="$2" recovery="$3"
    load_config() { :; }
    is_recovery() { return "$recovery"; }
    resolve_data_volume() { echo TARGET_WAS_ACCESSED; return 97; }
    main --dry-run "$action"
  ' "$script" "$definitions" "$command" "$recovery"
}

@test "suppress and bypass dry runs return before target resolution" {
  local entrypoint action
  for entrypoint in unleash unleash-standalone.sh; do
    for action in suppress bypass; do
      run_preview "$BATS_TEST_DIRNAME/../$entrypoint" "$action" 0
      [ "$status" -eq 0 ]
      [[ "$output" == *"[DRY RUN]"* ]]
      [[ "$output" != *"TARGET_WAS_ACCESSED"* ]]
    done
  done
}

@test "bypass dry run still rejects a booted OS" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    run_preview "$BATS_TEST_DIRNAME/../$entrypoint" bypass 1
    [ "$status" -ne 0 ]
    [[ "$output" == *"Full bypass must run from Recovery mode"* ]]
    [[ "$output" != *"TARGET_WAS_ACCESSED"* ]]
  done
}
