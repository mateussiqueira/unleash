#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../unleash"
}

@test "audit without an option reaches the privilege guard" {
  run bash -u "$SCRIPT" audit

  [ "$status" -ne 0 ]
  [[ "$output" == *"Audit needs sudo"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "--log-file without a path reports usage" {
  run bash -u "$SCRIPT" --log-file

  [ "$status" -ne 0 ]
  [[ "$output" == *"--log-file requires a path"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "monitor --webhook without a URL reports usage" {
  run bash -u "$SCRIPT" monitor --webhook

  [ "$status" -ne 0 ]
  [[ "$output" == *"--webhook requires a URL"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "config set without values reports usage" {
  run bash -u "$SCRIPT" config set

  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: ./unleash config set KEY VALUE"* ]]
  [[ "$output" != *"unbound variable"* ]]
}
