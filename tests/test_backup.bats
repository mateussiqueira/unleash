#!/usr/bin/env bats
# Tests for backup.sh - run with: bats tests/test_backup.bats

setup() {
  load '../lib/colors.sh'
  load '../lib/backup.sh'
  SCRIPT_DIR=$(mktemp -d)
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/private/etc"
  mkdir -p "$TEST_DIR/private/var/db/ConfigurationProfiles/Settings"
  echo "test" > "$TEST_DIR/private/etc/hosts"
  BACKUP_DIR="$SCRIPT_DIR/.unleash-backup"
}

teardown() {
  rm -rf "$SCRIPT_DIR" "$TEST_DIR"
}

@test "backup_state creates backup directory" {
  run backup_state "$TEST_DIR" 2>/dev/null || true
  [ -d "$BACKUP_DIR" ]
}

@test "backup_state saves hosts file" {
  run backup_state "$TEST_DIR" 2>/dev/null || true
  [ -f "$BACKUP_DIR/hosts.backup" ]
  run cat "$BACKUP_DIR/hosts.backup"
  [ "$output" = "test" ]
}

@test "has_backup returns false initially" {
  run has_backup
  [ "$status" -eq 1 ]
}

@test "has_backup returns true after backup" {
  backup_state "$TEST_DIR" 2>/dev/null || true
  run has_backup
  [ "$status" -eq 0 ]
}
