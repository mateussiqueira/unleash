#!/usr/bin/env bats

@test "dualboot keeps passwords out of diagnostics while preserving network preferences" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local definitions="$BATS_TEST_TMPDIR/$entrypoint.functions"
    local target="$BATS_TEST_TMPDIR/$entrypoint Data" log="$BATS_TEST_TMPDIR/$entrypoint.log"
    mkdir -p "$target/private/etc" "$target/private/var/db" "$target/Library/Preferences/SystemConfiguration"
    printf 'original network preferences\n' > "$target/Library/Preferences/SystemConfiguration/preferences.plist"
    printf 'original Wi-Fi networks\n' > "$target/Library/Preferences/com.apple.wifi.known-networks.plist"
    cp -R "$target/Library" "$BATS_TEST_TMPDIR/$entrypoint.before"
    sed '/^main "\$@"$/d' "$script" > "$definitions"
    run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
      source "$1"
      target="$2" logfile="$3"
      fixture_password="fixture-password-not-for-a-real-account"
      load_config() { :; }
      is_root() { return 0; }
      resolve_target_volumes() { printf "%s|%s\n" "$target-system" "$target"; }
      prompt_default() { printf -v "$1" "%s" "Fixture User"; }
      prompt_username() { printf -v "$1" "%s" fixture; }
      prompt_password() { printf -v "$1" "%s" "$fixture_password"; }
      find_available_uid() { echo 501; }
      create_admin_user() { [ "$5" = "$fixture_password" ]; }
      main --log-file "$logfile" dualboot
    ' "$script" "$definitions" "$target" "$log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Boot the target and login"* ]]
    [[ "$output" != *"fixture-password-not-for-a-real-account"* ]]
    [ -s "$log" ]
    run grep -F 'fixture-password-not-for-a-real-account' "$log"
    [ "$status" -eq 1 ]
    [ -f "$target/private/var/db/.AppleSetupDone" ]
    grep -q '0.0.0.0 deviceenrollment.apple.com' "$target/private/etc/hosts"
    diff -r "$BATS_TEST_TMPDIR/$entrypoint.before" "$target/Library"
  done
}
