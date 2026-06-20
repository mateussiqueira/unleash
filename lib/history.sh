show_history() {
  header "Unleash Event History"

  local logs=("/var/log/unleash-monitor.log" "/var/log/unleash-heal.log" "/var/log/unleash-monitor.err")
  local found=false

  for logfile in "${logs[@]}"; do
    if [ -f "$logfile" ] && [ -s "$logfile" ]; then
      found=true
      local name
      name=$(basename "$logfile")
      step "$name"
      while IFS= read -r line; do
        echo "  $line"
      done < "$logfile"
      echo ""
    fi
  done

  if [ "$found" = false ]; then
    info "No event logs found."
    info "Run 'sudo ./unleash monitor' or 'sudo ./unleash persist' first."
  fi

  step "Backup records"
  local backup_dir=".unleash-backup"
  if [ -d "$backup_dir" ] && [ -f "$backup_dir/timestamp" ]; then
    local ts
    ts=$(cat "$backup_dir/timestamp")
    echo "  Last backup: $ts"
  else
    echo "  No backup found"
  fi
}

clear_history() {
  local logs=("/var/log/unleash-monitor.log" "/var/log/unleash-heal.log" "/var/log/unleash-monitor.err")
  for logfile in "${logs[@]}"; do
    if [ -f "$logfile" ]; then
      : > "$logfile"
      success "Cleared: $logfile"
    fi
  done
}
