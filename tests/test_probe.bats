#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/probe.sh'
}

# Write a SystemVersion.plist fixture under a fake volume root.
make_sysversion() {
  local root="$1" product="$2" build="$3"
  local dir="$root/System/Library/CoreServices"
  mkdir -p "$dir"
  cat > "$dir/SystemVersion.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>ProductVersion</key><string>$product</string>
  <key>ProductBuildVersion</key><string>$build</string>
</dict>
</plist>
EOF
}

@test "probe_macos_version reads the product version from the volume plist" {
  local root="$BATS_TEST_TMPDIR/vol"
  make_sysversion "$root" "26.0" "25A123"
  run probe_macos_version "$root"
  [ "$status" -eq 0 ]
  [[ "$output" == 26.0* ]]
}

@test "probe_macos_version fails when the plist is absent" {
  run probe_macos_version "$BATS_TEST_TMPDIR/empty"
  [ "$status" -ne 0 ]
}

@test "probe_macos_major extracts the integer major from a dotted version" {
  run probe_macos_major "26.1.2"
  [ "$status" -eq 0 ]
  [ "$output" = "26" ]
}

@test "probe_macos_major rejects a non-numeric version" {
  run probe_macos_major "not-a-version"
  [ "$status" -ne 0 ]
}

@test "probe_codename maps macOS 26 to Tahoe" {
  run probe_codename "26"
  [ "$output" = "Tahoe" ]
}

@test "probe_compat marks macOS 26 (Tahoe) as testing" {
  run probe_compat "26"
  [ "$output" = "testing" ]
}

@test "probe_compat marks an unknown major as untested" {
  run probe_compat "99"
  [ "$output" = "untested" ]
}

@test "probe_enrollment reports dep when a cloud config record exists" {
  local root="$BATS_TEST_TMPDIR/vol"
  mkdir -p "$root/private/var/db/ConfigurationProfiles/Settings"
  touch "$root/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
  run probe_enrollment "$root"
  [ "$output" = "dep" ]
}

@test "probe_enrollment reports none on a clean volume" {
  local root="$BATS_TEST_TMPDIR/clean"
  mkdir -p "$root"
  run probe_enrollment "$root"
  [ "$output" = "none" ]
}

@test "cmd_probe --json emits version, enrollment and compat for Tahoe" {
  local root="$BATS_TEST_TMPDIR/vol"
  make_sysversion "$root" "26.0" "25A123"
  run cmd_probe --json "$root"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"codename":"Tahoe"'* ]]
  [[ "$output" == *'"compat":"testing"'* ]]
  [[ "$output" == *'"enrollment":"none"'* ]]
}

@test "cmd_probe is read-only and leaves the target volume untouched" {
  local root="$BATS_TEST_TMPDIR/vol"
  make_sysversion "$root" "26.0" "25A123"
  local before after
  before="$(find "$root" -type f | sort)"
  run cmd_probe "$root"
  [ "$status" -eq 0 ]
  after="$(find "$root" -type f | sort)"
  [ "$before" = "$after" ]
}
