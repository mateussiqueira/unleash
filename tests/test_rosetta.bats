#!/usr/bin/env bats

@test "suppression does not add hosts blocks for Rosetta configuration" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local target="$BATS_TEST_TMPDIR/$entrypoint"
    mkdir -p "$target/private/etc"
    printf '127.0.0.1 localhost\n' > "$target/private/etc/hosts"
    run bash -u -c '
      source <(sed '\''/^main "\$@"$/d'\'' "$1")
      PB=:
      suppress_enrollment "$2"
    ' "$script" "$script" "$target"
    [ "$status" -eq 0 ]
    run grep -q 'configuration[.]apple[.]com' "$target/private/etc/hosts"
    [ "$status" -eq 1 ]
    grep -q '^127.0.0.1 localhost$' "$target/private/etc/hosts"
  done
}
