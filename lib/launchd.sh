_launchd_script_path() {
  local script_path="${SCRIPT_PATH:-}"
  if [ -z "$script_path" ]; then
    script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  fi
  printf '%s' "$script_path" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}
