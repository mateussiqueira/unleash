install_monitor_launchdaemon() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"

  local unleash_src
  if [ -n "$SCRIPT_DIR" ]; then
    unleash_src="$SCRIPT_DIR/unleash"
  else
    unleash_src="$(cd "$(dirname "$0")" && pwd)/unleash"
  fi

  step "Installing monitor LaunchDaemon..."

  local plist_dir="${root}/Library/LaunchDaemons"
  local plist_path="${plist_dir}/com.unleash.monitor.plist"
  mkdir -p "$plist_dir"

  cat > "$plist_path" <<- PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.unleash.monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>${unleash_src} monitor</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>Nice</key>
    <integer>1</integer>
    <key>StandardOutPath</key>
    <string>/var/log/unleash-monitor.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/unleash-monitor.err</string>
</dict>
</plist>
PLIST

  chmod 644 "$plist_path"
  success "Monitor LaunchDaemon: $plist_path"

  if command -v launchctl &>/dev/null; then
    launchctl load "$plist_path" 2>/dev/null \
      && success "Monitor loaded (starts at boot)" \
      || info "Will load on next boot"
  fi
}

uninstall_monitor_launchdaemon() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"
  local plist_path="${root}/Library/LaunchDaemons/com.unleash.monitor.plist"

  if [ -f "$plist_path" ]; then
    step "Removing monitor LaunchDaemon..."
    if command -v launchctl &>/dev/null; then
      launchctl unload "$plist_path" 2>/dev/null || true
    fi
    rm -f "$plist_path"
    success "Monitor LaunchDaemon removed"
  else
    info "No monitor LaunchDaemon installed"
  fi
}

monitor_mdm() {
  header "MDM Monitor (continuous)"

  if ! is_root; then
    error_exit "Monitor requires sudo: sudo ./unleash monitor"
  fi

  local logfile="/var/log/unleash-monitor.log"
  local pidfile="/tmp/unleash-monitor.pid"

  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo -e "${YEL}Monitor already running (PID $(cat "$pidfile"))${NC}"
    echo -e "${YEL}Run 'sudo ./unleash monitor-stop' to stop it${NC}"
    return 0
  fi

  echo "$$" > "$pidfile"

  local interval=300
  local consecutive_failures=0
  local last_state=""
  local last_notification=0

  echo "$(date) Monitor started (interval ${interval}s)" >> "$logfile"

  local cfg="/private/var/db/ConfigurationProfiles/Settings"
  local hosts="/private/etc/hosts"

  trap 'echo "$(date) Monitor stopped" >> "$logfile"; rm -f "$pidfile"; exit 0' INT TERM

  while true; do
    local state="clean"
    local reason=""

    if [ -f "$cfg/.cloudConfigRecordFound" ]; then
      state="dirty"
      reason="DEP record found"
    fi

    if [ -f "$hosts" ] && ! grep -q "iprofiles.apple.com" "$hosts" 2>/dev/null; then
      state="dirty"
      reason="Hosts block missing"
    fi

    if command -v profiles &>/dev/null; then
      local enroll_state
      enroll_state=$(profiles status -type enrollment 2>/dev/null || true)
      if echo "$enroll_state" | grep -qi "Enrolled via DEP"; then
        state="dirty"
        reason="DEP enrollment active"
      fi
    fi

    if [ "$state" != "$last_state" ]; then
      echo "$(date) State change: $last_state -> $state ($reason)" >> "$logfile"
      last_state="$state"

      local now
      now=$(date +%s)
      if [ "$state" = "dirty" ] && [ $((now - last_notification)) -gt 3600 ]; then
        last_notification=$now
        if command -v osascript &>/dev/null; then
          osascript -e "display notification \"$reason\" with title \"Unleash MDM Alert\" subtitle \"MDM enrollment detected\"" 2>/dev/null || true
        fi
        heal_suppress ""
      fi
    fi

    if [ "$state" = "dirty" ]; then
      consecutive_failures=$((consecutive_failures + 1))
    else
      consecutive_failures=0
    fi

    if [ "$consecutive_failures" -ge 12 ]; then
      echo "$(date) CRITICAL: 12 consecutive dirty checks" >> "$logfile"
      if command -v osascript &>/dev/null; then
        osascript -e "display dialog \"MDM keeps coming back after 12 attempts. Something is persistently re-enrolling.\" with title \"Unleash\" buttons {\"OK\"} default button \"OK\"" 2>/dev/null || true
      fi
      consecutive_failures=0
    fi

    sleep "$interval" &
    wait $! 2>/dev/null || true
  done
}

stop_monitor() {
  local pidfile="/tmp/unleash-monitor.pid"
  if [ -f "$pidfile" ]; then
    local pid
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      echo -e "${GRN}Monitor stopped${NC}"
    else
      echo -e "${YEL}Monitor not running (stale PID)${NC}"
    fi
    rm -f "$pidfile"
  else
    echo -e "${YEL}Monitor not running${NC}"
  fi
}

monitor_status() {
  local pidfile="/tmp/unleash-monitor.pid"
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo -e "${GRN}Monitor running (PID $(cat "$pidfile"))${NC}"
    tail -5 /var/log/unleash-monitor.log 2>/dev/null || echo "  (no log entries yet)"
  else
    echo -e "${YEL}Monitor not running${NC}"
  fi
}
