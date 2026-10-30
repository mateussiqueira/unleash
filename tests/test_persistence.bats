#!/usr/bin/env bats

@test "persistence invokes renamed scripts with spaces and XML text literally" {
  local entrypoint
  for entrypoint in unleash unleash-standalone.sh; do
    local folder="$BATS_TEST_TMPDIR/$entrypoint/Tool Folder & <profile> \"quoted\""
    local target="$BATS_TEST_TMPDIR/$entrypoint/Target"
    local script="$folder/renamed standalone.sh"
    local definitions="$BATS_TEST_TMPDIR/$entrypoint.functions"
    mkdir -p "$folder" "$target/Library"
    printf '#!/bin/bash\nprintf "ACTION=%%s\\n" "$1"\n' > "$script"
    if [ "$entrypoint" = unleash ]; then
      ln -s "$BATS_TEST_DIRNAME/../lib" "$folder/lib"
    fi
    sed '/^main "\$@"$/d' "$BATS_TEST_DIRNAME/../$entrypoint" > "$definitions"
    run "${UNLEASH_TEST_SHELL:-bash}" -u -c '
      unset SCRIPT_DIR SCRIPT_PATH
      source "$1"
      expected="$2/Library/LaunchDaemons"
      mkdir() {
        [ "$#" -eq 2 ] && [ "$1" = -p ] && [ "$2" = "$expected" ] || return 97
        command mkdir "$@"
      }
      install_persist_launchdaemon "$2"
    ' "$script" "$definitions" "$target"
    [ "$status" -eq 0 ]
    run python3 - "$target/Library/LaunchDaemons/com.unleash.heal.plist" "$script" <<'PY'
import plistlib,subprocess,sys
with open(sys.argv[1],'rb') as source:
    data=plistlib.load(source)
expected=['/bin/bash',sys.argv[2],'heal']
assert data['ProgramArguments']==expected, data['ProgramArguments']
result=subprocess.run(expected,capture_output=True,text=True,timeout=5)
assert result.returncode==0, result.stderr
assert result.stdout=='ACTION=heal\n', result.stdout
PY
    [ "$status" -eq 0 ]
  done
}
