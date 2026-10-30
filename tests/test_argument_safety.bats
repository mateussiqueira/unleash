#!/usr/bin/env bats

run_cli() {
  local script="$1"; shift
  local definitions="$BATS_TEST_TMPDIR/${script##*/}.functions"
  sed '/^main "\$@"$/d' "$script" > "$definitions"
  run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
    source "$1"
    shift
    load_config() { :; }
    is_root() { return 1; }
    is_recovery() { return 1; }
    cmd_interactive_normal() { printf "interactive verbose=%s\n" "$VERBOSE"; }
    main "$@"
  ' "$script" "$definitions" "$@"
}

run_capture() {
  local script="$1"; shift
  local definitions="$BATS_TEST_TMPDIR/${script##*/}.functions"
  sed '/^main "\$@"$/d' "$script" > "$definitions"
  run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
    source "$1"
    shift
    load_config() { :; }
    cmd_config() {
      printf "dry=%s verbose=%s log=<%s>\nargc=%s\n" "$DRY_RUN" "$VERBOSE" "$LOG_FILE" "$#"
      printf "<%s>\n" "$@"
    }
    main "$@"
  ' "$script" "$definitions" "$@"
}

@test "optional CLI arguments reach usage or privilege guards under nounset" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    run_cli "$script" audit
    [ "$status" -ne 0 ]; [[ "$output" == *"Audit needs sudo"* ]]
    run_cli "$script" --log-file
    [ "$status" -ne 0 ]; [[ "$output" == *"--log-file requires a path"* ]]
    run_cli "$script" monitor --webhook
    [ "$status" -ne 0 ]; [[ "$output" == *"--webhook requires a URL"* ]]
    run_cli "$script" config set
    [ "$status" -ne 0 ]; [[ "$output" == *"Usage: ./unleash config set KEY VALUE"* ]]
    run_cli "$script" config unset
    [ "$status" -ne 0 ]; [[ "$output" == *"Usage: ./unleash config unset KEY"* ]]
  done
}

@test "CLI values retain spaces quotes empty strings and literal shell syntax" {
  local entrypoint value
  for entrypoint in unleash unleash-standalone.sh; do
    for value in 'a b $(printf injected) "quoted"' ''; do
      run_capture "$BATS_TEST_DIRNAME/../$entrypoint" config set LOG_FILE "$value"
      [ "$status" -eq 0 ]
      local expected
      expected=$(printf 'dry=false verbose=false log=<>\nargc=4\n<config>\n<set>\n<LOG_FILE>\n<%s>' "$value")
      [ "$output" = "$expected" ]
    done
  done
}

@test "global flags around the command persist in the command shell" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    run_capture "$BATS_TEST_DIRNAME/../$entrypoint" --dry-run config --verbose set LOG_FILE value --log-file 'a b.log'
    [ "$status" -eq 0 ]
    [[ "$output" == 'dry=true verbose=true log=<a b.log>'* ]]
    [[ "$output" == *'argc=4'* ]]
  done
}

@test "global flags without a command preserve an empty argument list" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    run_cli "$BATS_TEST_DIRNAME/../$entrypoint" --verbose
    [ "$status" -eq 0 ]
    [ "$output" = 'interactive verbose=true' ]
  done
}

@test "CLI option terminator preserves values that look like global options" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    run_capture "$BATS_TEST_DIRNAME/../$entrypoint" config set LOG_LEVEL -- --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == 'dry=false verbose=false log=<>'* ]]
    [[ "$output" == *'<--verbose>' ]]
  done
}

@test "log-file rejects an empty path or another option as its missing value" {
  local entrypoint value
  for entrypoint in unleash unleash-standalone.sh; do
    for value in '' --dry-run; do
      run_cli "$BATS_TEST_DIRNAME/../$entrypoint" --log-file "$value" version
      [ "$status" -ne 0 ]
      [[ "$output" == *"--log-file requires a path"* ]]
    done
  done
}
