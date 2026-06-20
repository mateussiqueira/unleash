
DISCORD_BOT_DIR="/tmp/unleash-discord"
DISCORD_BOT_SCRIPT="${DISCORD_BOT_DIR}/bot.sh"
DISCORD_BOT_PID="${DISCORD_BOT_DIR}/bot.pid"

cmd_discord_bot_install() {
  header "Install Discord Bot"

  local token="${1:-}"
  local channel_id="${2:-}"
  if [ -z "$token" ]; then
    read -p "Discord Bot Token: " token
  fi
  if [ -z "$channel_id" ]; then
    read -p "Discord Channel ID: " channel_id
  fi
  if [ -z "$token" ] || [ -z "$channel_id" ]; then
    error_exit "Token and channel ID are required"
  fi

  mkdir -p "$DISCORD_BOT_DIR"

  cat > "$DISCORD_BOT_SCRIPT" <<- BOT
#!/bin/bash
# Unleash Discord Bot — monitors MDM and sends alerts
TOKEN="$token"
CHANNEL_ID="$channel_id"
LAST_STATE=""
while true; do
  STATE="clean"
  if [ -f "/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" ]; then
    STATE="dirty"
  fi
  if [ "\$STATE" != "\$LAST_STATE" ] && [ "\$STATE" = "dirty" ]; then
    curl -s -X POST "https://discord.com/api/v10/channels/\$CHANNEL_ID/messages" \
      -H "Authorization: Bot \$TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"content":"🚨 **Unleash Alert** — MDM enrollment detected on '"$(hostname)"'"}'
  fi
  LAST_STATE="\$STATE"
  sleep 300
done
BOT
  chmod +x "$DISCORD_BOT_SCRIPT"

  nohup bash "$DISCORD_BOT_SCRIPT" > /dev/null 2>&1 &
  local pid=$!
  echo "$pid" > "$DISCORD_BOT_PID"
  success "Discord bot started (PID $pid)"
  info "To stop: ./unleash discord-bot-stop"
}

cmd_discord_bot_stop() {
  if [ -f "$DISCORD_BOT_PID" ]; then
    local pid
    pid=$(cat "$DISCORD_BOT_PID")
    kill "$pid" 2>/dev/null || true
    rm -f "$DISCORD_BOT_PID"
    success "Discord bot stopped"
  else
    info "Discord bot not running"
  fi
}

cmd_discord_bot_status() {
  if [ -f "$DISCORD_BOT_PID" ]; then
    local pid
    pid=$(cat "$DISCORD_BOT_PID")
    if kill -0 "$pid" 2>/dev/null; then
      echo -e "${GRN}Discord bot running (PID $pid)${NC}"
    else
      echo -e "${YEL}Discord bot not running (stale PID)${NC}"
    fi
  else
    echo -e "${YEL}Discord bot not installed${NC}"
  fi
}
