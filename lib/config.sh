CONFIG_FILE="$HOME/.unleash.conf"

load_config() {
  [ -f "$CONFIG_FILE" ] || return 0

  while IFS='=' read -r key value; do
    key="${key// /}"
    value="${value// /}"
    [ -z "$key" ] && continue
    case "$key" in
      WEBHOOK) DISCORD_WEBHOOK="$value" ;;
      LOG_LEVEL) [ "$value" = "verbose" ] && VERBOSE=true ;;
      LOG_FILE) LOG_FILE="$value" ;;
    esac
  done < "$CONFIG_FILE"
}

save_config() {
  local key="$1"
  local value="$2"
  local tmp

  [ -f "$CONFIG_FILE" ] || touch "$CONFIG_FILE"

  if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    sed -i '' "s/^${key}=.*/${key}=${value}/" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
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
      local key="$3"
      local value="$4"
      [ -z "$key" ] || [ -z "$value" ] && {
        info "Usage: ./unleash config set KEY VALUE"
        info "Keys: WEBHOOK, LOG_LEVEL (verbose), LOG_FILE"
        return 1
      }
      save_config "$key" "$value"
      ;;
    unset)
      local key="$3"
      [ -z "$key" ] && { info "Usage: ./unleash config unset KEY"; return 1; }
      if [ -f "$CONFIG_FILE" ]; then
        sed -i '' "/^${key}=/d" "$CONFIG_FILE"
        success "Removed $key from config"
      fi
      ;;
    *)
      info "Usage: ./unleash config {show|set KEY VALUE|unset KEY}"
      ;;
  esac
}
