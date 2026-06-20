
TELEMETRY_FILE="$HOME/.unleash-telemetry"

telemetry_opt_in() {
  local val="${1:-}"
  if [ "$val" = "yes" ] || [ "$val" = "true" ] || [ "$val" = "1" ]; then
    echo "enabled" > "$TELEMETRY_FILE"
    success "Telemetry enabled"
  elif [ "$val" = "no" ] || [ "$val" = "false" ] || [ "$val" = "0" ]; then
    rm -f "$TELEMETRY_FILE"
    success "Telemetry disabled"
  else
    local current="disabled"
    [ -f "$TELEMETRY_FILE" ] && current="enabled"
    info "Telemetry: $current"
    info "Usage: sudo ./unleash telemetry on|off"
  fi
}

telemetry_is_enabled() {
  [ -f "$TELEMETRY_FILE" ] && return 0
  return 1
}

telemetry_send() {
  telemetry_is_enabled || return 0
  local event="$1"
  local data="${2:-{}}"
  local url="https://unleash-telemetry.mateussiqueira.workers.dev/event"
  local payload
  payload=$(printf '{"event":"%s","version":"%s","arch":"%s","os":"%s","data":%s}' \
    "$event" "$VERSION" "$(uname -m)" "$(uname -s)" "$data")
  curl -s -o /dev/null -w "" -H "Content-Type: application/json" \
    -d "$payload" "$url" 2>/dev/null || true
}
