#!/usr/bin/env bats

check_optional_record() {
  local kind="$1" entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local script="$BATS_TEST_DIRNAME/../$entrypoint"
    local definitions="$BATS_TEST_TMPDIR/$entrypoint.functions"
    local target="$BATS_TEST_TMPDIR/$entrypoint-volume"
    sed '/^main "\$@"$/d' "$script" > "$definitions"
    python3 - "$target" "$kind" <<'PY'
import pathlib, plistlib, sys
settings = pathlib.Path(sys.argv[1]) / "private/var/db/ConfigurationProfiles/Settings"
settings.mkdir(parents=True)
records = {
    "empty": {},
    "apple": {"URL": "https://deviceenrollment.apple.com/enroll", "OrganizationName": "Example"},
    "orgless": {"URL": "https://mdm.example.org/enroll"},
}
(settings / ".cloudConfigRecordFound").write_bytes(plistlib.dumps(records[sys.argv[2]]))
PY
    run "${UNLEASH_TEST_SHELL:-bash}" -eu -o pipefail -c '
      source "$1"
      target="$2"
      load_config() { :; }
      resolve_data_volume() { printf "%s\n" "$target"; }
      main suppress
    ' "$script" "$definitions" "$target"
    [ "$status" -eq 0 ]
    [ -f "$target/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound" ]
    [ -f "$target/private/var/db/com.apple.xpc.launchd/disabled.plist" ]
    grep -q '0.0.0.0 iprofiles.apple.com' "$target/private/etc/hosts"
    if [ "$kind" = orgless ]; then
      grep -q '0.0.0.0 mdm.example.org' "$target/private/etc/hosts"
    fi
  done
}

@test "suppress completes when the activation record has no optional metadata" {
  check_optional_record empty
}

@test "suppress completes when the activation record contains only Apple URLs" {
  check_optional_record apple
}

@test "suppress preserves an organization host without an organization name" {
  check_optional_record orgless
}
