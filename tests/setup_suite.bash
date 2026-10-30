setup_suite() {
  local suite_dir
  suite_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  export UNLEASH_TEST_ROOT="$BATS_SUITE_TMPDIR"
  export TMPDIR="$UNLEASH_TEST_ROOT/tmp"
  local mock_bin="$UNLEASH_TEST_ROOT/bin"
  mkdir -p "$TMPDIR" "$mock_bin"
  local tool
  for tool in sudo diskutil profiles security launchctl pfctl pkill pgrep killall \
    dscacheutil defaults curl host plutil PlistBuddy dscl fdesetup chflags \
    osascript ioreg ifconfig systemextensionsctl networksetup; do
    cp "$suite_dir/helpers/platform.py" "$mock_bin/$tool"
    chmod +x "$mock_bin/$tool"
  done
  export PATH="$mock_bin:$PATH"
  export PB="$mock_bin/PlistBuddy"
  export VERSION=2.0.0
  export SCRIPT_DIR="$suite_dir/.."
  export LIB_DIR="$SCRIPT_DIR/lib"
}
