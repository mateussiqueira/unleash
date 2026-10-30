#!/usr/bin/env bats

setup() {
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT/scripts" "$PROJECT/lib"
  cp "$BATS_TEST_DIRNAME/../scripts/check-shell.py" "$PROJECT/scripts/"
  cat > "$PROJECT/unleash" <<'SH'
#!/bin/bash
for _lib in sample; do
  source "lib/$_lib.sh"
done
sample
SH
  printf 'sample() { :; }\n' > "$PROJECT/lib/sample.sh"
  printf '#!/bin/bash\n' > "$PROJECT/unleash-standalone.sh"
}

@test "lint reports sourced module findings without executing the application" {
  export LINT_TEST_MARKER="$BATS_TEST_TMPDIR/app-executed"
  printf 'sample() { echo $missing; }\n: > "$LINT_TEST_MARKER"\n' > "$PROJECT/lib/sample.sh"
  run python3 "$PROJECT/scripts/check-shell.py"
  [ "$status" -ne 0 ]
  [[ "$output" == *"lib/sample.sh:1:"* ]]
  [[ "$output" == *"SC2086"* ]]
  [ ! -f "$LINT_TEST_MARKER" ]
}

@test "lint checks syntax in every library" {
  printf 'sample() {\n' > "$PROJECT/lib/sample.sh"
  run python3 "$PROJECT/scripts/check-shell.py"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sample.sh"* ]]
}

@test "lint does not install tools after an analysis failure" {
  cp "$BATS_TEST_DIRNAME/../Makefile" "$PROJECT/Makefile"
  local mock_bin="$BATS_TEST_TMPDIR/lint-bin"
  mkdir -p "$mock_bin"
  ln -s "$(command -v python3)" "$mock_bin/python3"
  ln -s "$(command -v bash)" "$mock_bin/bash"
  printf '#!/bin/sh\nprintf "[]"\nexit 1\n' > "$mock_bin/shellcheck"
  export TEST_BREW_MARKER="$BATS_TEST_TMPDIR/brew-called"
  printf '#!/bin/sh\n: > "$TEST_BREW_MARKER"\n' > "$mock_bin/brew"
  chmod +x "$mock_bin/shellcheck" "$mock_bin/brew"
  run env PATH="$mock_bin" "$(command -v make)" -C "$PROJECT" lint
  [ "$status" -ne 0 ]
  [ ! -f "$TEST_BREW_MARKER" ]
}
