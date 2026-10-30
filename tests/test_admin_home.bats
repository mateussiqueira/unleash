#!/usr/bin/env bats

run_admin_home() {
  local script="$1" mode="$2"
  local definitions="$BATS_TEST_TMPDIR/admin.functions"
  local target="$BATS_TEST_TMPDIR/External Data"
  mkdir -p "$target/private/var/db" "$target/private/etc" "$target/Users"
  sed '/^main "\$@"$/d' "$script" > "$definitions"
  run "${UNLEASH_TEST_SHELL:-bash}" -c '
    source "$1"
    target="$2" mode="$3" calls="$4"
    dscl() {
      if [ "$4" = -read ]; then [ "$mode" = existing-user ]; return; fi
      echo mutation >> "$calls"
    }
    chown() {
      [ "$mode" != ownership-fails ] || return 77
      [ "$#" -eq 2 ] && [ "$1" = 501:20 ] && [ "$2" = "$target/Users/fixture" ] || return 98
      [ -d "$2" ] || return 99
      echo ownership >> "$calls"
    }
    load_config() { :; }
    is_root() { return 0; }
    resolve_target_volumes() { printf "%s|%s\n" "$target-system" "$target"; }
    prompt_default() { printf -v "$1" "%s" "Fixture User"; }
    prompt_username() { printf -v "$1" "%s" fixture; }
    prompt_password() { printf -v "$1" "%s" fixture-password; }
    find_available_uid() { echo 501; }
    main dualboot
  ' "$script" "$definitions" "$target" "$mode" "$BATS_TEST_TMPDIR/calls"
}

@test "dualboot assigns the new home to the target UID and staff group" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    run_admin_home "$BATS_TEST_DIRNAME/../$entrypoint" fresh
    [ "$status" -eq 0 ]
    grep -qx ownership "$BATS_TEST_TMPDIR/calls"
    [ -f "$BATS_TEST_TMPDIR/External Data/private/var/db/.AppleSetupDone" ]
    rm -r "$BATS_TEST_TMPDIR/External Data"
    rm "$BATS_TEST_TMPDIR/calls"
  done
}

@test "dualboot stops before setup and network markers when home ownership fails" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    run_admin_home "$BATS_TEST_DIRNAME/../$entrypoint" ownership-fails
    [ "$status" -ne 0 ]
    [[ "$output" != *"Admin 'fixture' created"* ]]
    [ ! -e "$BATS_TEST_TMPDIR/External Data/private/var/db/.AppleSetupDone" ]
    [ ! -e "$BATS_TEST_TMPDIR/External Data/private/etc/hosts" ]
    rm -r "$BATS_TEST_TMPDIR/External Data"
  done
}

@test "dualboot preserves existing accounts homes and dangling home symlinks" {
  local entrypoint mode
  for entrypoint in unleash unleash-standalone.sh; do
    for mode in existing-user existing-home home-symlink; do
      local target="$BATS_TEST_TMPDIR/External Data"
      mkdir -p "$target/Users"
      case "$mode" in
        existing-home) mkdir "$target/Users/fixture"; echo preserved > "$target/Users/fixture/sentinel" ;;
        home-symlink) ln -s "$target/missing" "$target/Users/fixture" ;;
      esac
      run_admin_home "$BATS_TEST_DIRNAME/../$entrypoint" "$mode"
      [ "$status" -ne 0 ]
      [ ! -e "$BATS_TEST_TMPDIR/calls" ]
      [ ! -e "$target/private/var/db/.AppleSetupDone" ]
      case "$mode" in
        existing-home) grep -qx preserved "$target/Users/fixture/sentinel" ;;
        home-symlink) [ -L "$target/Users/fixture" ]; [ ! -e "$target/missing" ] ;;
      esac
      rm -r "$target"
    done
  done
}
