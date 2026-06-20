#!/usr/bin/env bats
# Tests for validate.sh - run with: bats tests/test_validate.bats

setup() {
  load '../lib/colors.sh'
  load '../lib/validate.sh'
}

@test "validate_username accepts valid usernames" {
  run validate_username "apple"
  [ "$status" -eq 0 ]
  run validate_username "test-user"
  [ "$status" -eq 0 ]
  run validate_username "test_user"
  [ "$status" -eq 0 ]
}

@test "validate_username rejects empty" {
  run validate_username ""
  [ "$status" -eq 1 ]
}

@test "validate_username rejects long names" {
  local long="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  run validate_username "$long"
  [ "$status" -eq 1 ]
}

@test "validate_username rejects special chars" {
  run validate_username "user name"
  [ "$status" -eq 1 ]
  run validate_username "user.name"
  [ "$status" -eq 1 ]
}

@test "validate_password accepts valid passwords" {
  run validate_password "1234"
  [ "$status" -eq 0 ]
  run validate_password "correct horse battery staple"
  [ "$status" -eq 0 ]
}

@test "validate_password rejects empty" {
  run validate_password ""
  [ "$status" -eq 1 ]
}

@test "validate_password rejects short" {
  run validate_password "ab"
  [ "$status" -eq 1 ]
}
