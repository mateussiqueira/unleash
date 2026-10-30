CONFIG_FILE="$HOME/.unleash.conf"

load_config() {
  [ -f "$CONFIG_FILE" ] || return 0
  local key value
  while IFS='=' read -r key value || [ -n "$key" ]; do
    key="${key// /}"
    [ -z "$key" ] && continue
    case "$key" in
      WEBHOOK) DISCORD_WEBHOOK="$value" ;;
      LOG_LEVEL) [ "$value" = "verbose" ] && VERBOSE=true ;;
      LOG_FILE) LOG_FILE="$value" ;;
    esac
  done < "$CONFIG_FILE"
}

_rewrite_config() {
  local key="$1"
  local value="$2"
  local tmp
  [ -f "$CONFIG_FILE" ] || touch "$CONFIG_FILE"
  tmp=$(mktemp "${CONFIG_FILE}.XXXXXX") || return 1
  if ! UNLEASH_CONFIG_KEY="$key" UNLEASH_CONFIG_VALUE="$value" \
    UNLEASH_CONFIG_OPERATION="${3:-set}" awk '
      BEGIN { key=ENVIRON["UNLEASH_CONFIG_KEY"]; value=ENVIRON["UNLEASH_CONFIG_VALUE"];
              operation=ENVIRON["UNLEASH_CONFIG_OPERATION"] }
      index($0, key "=")==1 { if (!found++ && operation=="set") print key "=" value; next }
      { print }
      END { if (!found && operation=="set") print key "=" value }
    ' "$CONFIG_FILE" > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$CONFIG_FILE"
}

save_config() {
  local key="$1" value="$2"
  _rewrite_config "$key" "$value" || return 1
  success "Saved $key to $CONFIG_FILE"
}

cmd_config() {
  header "Configuration"

  case "${2:-show}" in
    show)
      if [ ! -f "$CONFIG_FILE" ]; then
        info "No config file at $CONFIG_FILE"
        return 0
      fi
      step "Current settings ($CONFIG_FILE)"
      cat "$CONFIG_FILE" | sed 's/^/  /'
      ;;
    set)
      local key="${3:-}"
      local value="${4:-}"
      [ -z "$key" ] || [ -z "$value" ] && {
        info "Usage: ./unleash config set KEY VALUE"
        info "Keys: WEBHOOK, LOG_LEVEL (verbose), LOG_FILE"
        return 1
      }
      save_config "$key" "$value"
      ;;
    unset)
      local key="${3:-}"
      [ -z "$key" ] && { info "Usage: ./unleash config unset KEY"; return 1; }
      if [ -f "$CONFIG_FILE" ]; then
        _rewrite_config "$key" "" unset || return 1
        success "Removed $key from config"
      fi
      ;;
    *)
      info "Usage: ./unleash config {show|set KEY VALUE|unset KEY}"
      ;;
  esac
}
