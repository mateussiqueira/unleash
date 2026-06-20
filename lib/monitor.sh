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
