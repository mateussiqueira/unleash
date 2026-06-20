do_self_update() {
  header "Unleash Update"

  if ! command -v curl &>/dev/null; then
    error_exit "curl required for update"
  fi

  local repo="mateussiqueira/unleash"
  local api_url="https://api.github.com/repos/${repo}/releases/latest"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local current_sha
  current_sha=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")

  begin "Checking latest release"
  local release_data
  release_data=$(curl -s "$api_url" 2>/dev/null || true)
  local latest_tag
  latest_tag=$(echo "$release_data" | grep '"tag_name"' | head -1 | sed -E 's/.*"v?([^"]+)".*/\1/')
  local latest_sha
  latest_sha=$(echo "$release_data" | grep '"target_commitish"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

  if [ -z "$latest_tag" ]; then
    end_fail; echo "     No network or invalid response"
    rm -rf "$tmp_dir"
    return 1
  fi
  end_ok; echo "     Latest: v$latest_tag"

  if [ "v$latest_tag" = "$(echo "v$VERSION")" ]; then
    success "Already up to date (v$VERSION)"
    rm -rf "$tmp_dir"
    return 0
  fi

  info "Updating from v$VERSION to v$latest_tag..."

  begin "Downloading latest unleash"
  local dl_url="https://raw.githubusercontent.com/${repo}/main/unleash"
  local tmp="$tmp_dir/unleash"
  if curl -sL "$dl_url" -o "$tmp" && [ -s "$tmp" ]; then
    end_ok
  else
    end_fail; error_exit "Download failed"
  fi

  begin "Verifying syntax"
  if bash -n "$tmp" 2>/dev/null; then
    end_ok
  else
    end_fail; error_exit "Downloaded script has syntax errors"
  fi

  local target="${0:-unleash}"
  if [ ! -w "$target" ]; then
    info "$target not writable, trying sudo..."
    cp "$tmp" "$target" 2>/dev/null || sudo cp "$tmp" "$target" 2>/dev/null || {
      error_exit "Cannot write to $target (run with sudo)"
    }
  else
    cp "$tmp" "$target"
  fi
  chmod +x "$target" 2>/dev/null || sudo chmod +x "$target" 2>/dev/null || true

  rm -rf "$tmp_dir"
  success "Updated to v$latest_tag"
  info "Run again to use new version"
}
