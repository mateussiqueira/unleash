#!/usr/bin/env bats

suppress_fixture() {
  local script="$1" target="$2"
  local action="${3:-suppress_enrollment}" simulation="${4:-false}"
  run bash -u -c '
    source <(sed '\''/^main "\$@"$/d'\'' "$1")
    DRY_RUN="$4"
    "$3" "$2"
  ' "$script" "$script" "$target" "$action" "$simulation"
  [ "$status" -eq 0 ]
}

@test "heal repairs old Rosetta blocks even when suppression is otherwise intact" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local target="$BATS_TEST_TMPDIR/$entrypoint" hosts
    hosts="$target/private/etc/hosts"
    suppress_fixture "$script" "$target"
    printf '0.0.0.0 configuration.apple.com\n::      configuration.apple.com\n' >> "$hosts"
    suppress_fixture "$script" "$target" heal_suppress
    run grep -q 'configuration[.]apple[.]com' "$hosts"
    [ "$status" -eq 1 ]
  done
}

@test "heal dry run preserves old Rosetta entries" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local target="$BATS_TEST_TMPDIR/$entrypoint" hosts
    hosts="$target/private/etc/hosts"
    suppress_fixture "$script" "$target"
    printf '0.0.0.0 configuration.apple.com\n::      configuration.apple.com\n' >> "$hosts"
    cp "$hosts" "$target/original"
    suppress_fixture "$script" "$target" heal_suppress true
    cmp "$target/original" "$hosts"
    [ ! -e "$hosts.unleash-rosetta.bak" ]
  done
}

@test "suppression does not add hosts blocks for Rosetta configuration" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local target="$BATS_TEST_TMPDIR/$entrypoint"
    mkdir -p "$target/private/etc"
    printf '127.0.0.1 localhost\n' > "$target/private/etc/hosts"
    suppress_fixture "$script" "$target"
    run grep -q 'configuration[.]apple[.]com' "$target/private/etc/hosts"
    [ "$status" -eq 1 ]
    grep -q '^127.0.0.1 localhost$' "$target/private/etc/hosts"
  done
}

@test "suppression repairs its old Rosetta blocks with an unchanged backup on rerun" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local target="$BATS_TEST_TMPDIR/$entrypoint" hosts
    hosts="$target/private/etc/hosts"
    mkdir -p "$(dirname "$hosts")"
    printf '127.0.0.1 localhost\n# Added by unleash — DEP enrollment block\n0.0.0.0 configuration.apple.com\n::      configuration.apple.com\n' > "$hosts"
    cp "$hosts" "$target/original"
    suppress_fixture "$script" "$target"
    run grep -q 'configuration[.]apple[.]com' "$hosts"
    [ "$status" -eq 1 ]
    cmp "$target/original" "$hosts.unleash-rosetta.bak"
    cp "$hosts" "$target/repaired"
    suppress_fixture "$script" "$target"
    cmp "$target/repaired" "$hosts"
    cmp "$target/original" "$hosts.unleash-rosetta.bak"
  done
}

@test "suppression preserves Rosetta blocks outside its generated section" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local target="$BATS_TEST_TMPDIR/$entrypoint" hosts
    hosts="$target/private/etc/hosts"
    mkdir -p "$(dirname "$hosts")"
    printf '0.0.0.0 configuration.apple.com\n:: configuration.apple.com manual.alias\n' > "$hosts"
    suppress_fixture "$script" "$target"
    grep -Fxq '0.0.0.0 configuration.apple.com' "$hosts"
    grep -Fxq ':: configuration.apple.com manual.alias' "$hosts"
    [ ! -e "$hosts.unleash-rosetta.bak" ]
  done
}
