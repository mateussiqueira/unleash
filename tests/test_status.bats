#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/status.sh'
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/private/etc"
  mkdir -p "$TEST_DIR/private/var/db/ConfigurationProfiles/Settings"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "check_mdm_status exits cleanly" {
  run check_mdm_status "$TEST_DIR" 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "deep_status exits cleanly" {
  run deep_status 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "deep_status_json contains braces" {
  run deep_status_json 2>/dev/null || true
  echo "$output" | grep -q "}"
}

@test "deep_status_json counts a single matching process without subtracting it" {
  profiles() {
    if [ "$1" = -C ]; then echo '<key>ProfileDisplayName</key>';
    else echo 'MDM enrollment: No'; fi
  }
  sudo() { "$@"; }
  pgrep() { echo '42 mdmclient'; }
  ps() { echo 'test 42 0.0 0.0 1 1 ? S 00:00 0:00 mdmclient'; }
  run deep_status_json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; assert json.load(sys.stdin)["running_mdm_processes"] == 1'
}

@test "text audit completes with zero profiles under nounset" {
  run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
    source "$1/lib/colors.sh"
    source "$1/lib/status.sh"
    pf_status() { :; }
    deep_status
  ' bash "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
  [[ "$output" == *"Risk:"* ]]
  [[ ! "$output" =~ integer.*expected ]]
}

@test "audit and report JSON contain numeric zero counts under nounset" {
  local module function_name field
  for module in status report; do
    if [ "$module" = status ]; then function_name=deep_status_json; field=profile_count;
    else function_name=generate_report_json; field=installed_profiles; fi
    run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
      source "$1/lib/colors.sh"
      source "$1/lib/$2.sh"
      grep() {
        if [ "${1:-}" = -c ] && [ "${3:-}" = /private/etc/hosts ]; then echo 0; return 1; fi
        command grep "$@"
      }
      "$3"
    ' bash "$BATS_TEST_DIRNAME/.." "$module" "$function_name"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data[sys.argv[1]] == 0; assert data.get("hosts_blocked",0) == 0' "$field"
  done
}
