GPG_KEY_URL="https://raw.githubusercontent.com/mateussiqueira/unleash/main/.github/unleash.gpg"

import_gpg_key() {
  local tmp_key
  tmp_key=$(mktemp)
  if curl -sL "$GPG_KEY_URL" -o "$tmp_key" 2>/dev/null; then
    gpg --import "$tmp_key" 2>/dev/null || true
  fi
  rm -f "$tmp_key"
}

verify_gpg_signature() {
  local file="$1"
  local sig="$2"
  if ! command -v gpg &>/dev/null; then
    warn "GPG not available — skipping signature verification"
    return 0
  fi
  import_gpg_key
  if gpg --verify "$sig" "$file" 2>/dev/null; then
    info "GPG signature valid"
    return 0
  else
    warn "GPG signature invalid or missing"
    echo -n "Continue without verification? [y/N] "
    read -r ans
    [ "$ans" != "y" ] && [ "$ans" != "Y" ] && error_exit "Aborted"
    return 0
  fi
}

do_self_update() {
  header "Unleash Update"

  if ! command -v curl &>/dev/null; then
    error_exit "curl required for update"
  fi

  local repo="mateussiqueira/unleash"
  local api_url="https://api.github.com/repos/${repo}/releases/latest"
  local tmp_dir
  tmp_dir=$(mktemp -d)

  begin "Checking latest release"
  local release_data
  release_data=$(curl -s "$api_url" 2>/dev/null || true)
  local latest_tag
  latest_tag=$(echo "$release_data" | grep '"tag_name"' | head -1 | sed -E 's/.*"v?([^"]+)".*/\1/')

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
  local sig_url="${dl_url}.sig"
  local tmp="$tmp_dir/unleash"
  local sig_tmp="$tmp_dir/unleash.sig"
  if curl -sL "$dl_url" -o "$tmp" && [ -s "$tmp" ]; then
    curl -sL "$sig_url" -o "$sig_tmp" 2>/dev/null || true
    end_ok
  else
    end_fail; error_exit "Download failed"
  fi

  if [ -s "$sig_tmp" ]; then
    begin "Verifying GPG signature"
    verify_gpg_signature "$tmp" "$sig_tmp"
    end_ok
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
