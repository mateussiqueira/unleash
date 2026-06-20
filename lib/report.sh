generate_report() {
  if [ "${1:-}" = "--json" ]; then
    generate_report_json
    return
  fi
  header "Unleash System Report"

  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "Generated: $ts"
  echo "Version:   $VERSION"
  echo ""

  step "MDM Enrollment State"
  if command -v profiles &>/dev/null; then
    sudo profiles status -type enrollment 2>/dev/null || echo "  (cannot determine)"
  fi

  local cfg="/private/var/db/ConfigurationProfiles/Settings"
  if [ -f "$cfg/.cloudConfigRecordFound" ]; then
    local org
    org=$(plutil -convert xml1 -o - "$cfg/.cloudConfigRecordFound" 2>/dev/null \
      | grep -iA1 OrganizationName | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
    echo "  DEP record: FOUND${org:+ (Organization: $org)}"
  else
    echo "  DEP record: clean"
  fi
  echo ""

  step "Installed Profiles"
  if command -v profiles &>/dev/null; then
    local count
    count=$(sudo profiles -C -output=xml 2>/dev/null | grep -c "ProfileDisplayName" || echo 0)
    if [ "$count" -gt 0 ]; then
      echo "  $count profile(s) installed"
      sudo profiles -C -output=xml 2>/dev/null | grep -A1 "ProfileDisplayName" | grep "<string>" \
        | sed 's/.*<string>\(.*\)<\/string>.*/    - \1/'
    else
      echo "  No profiles installed"
    fi
  fi
  echo ""

  step "Firewall"
  if command -v pfctl &>/dev/null; then
    pfctl -si 2>/dev/null | grep -E "Status|Enabled" || echo "  pf not enabled"
    echo ""
    pfctl -a "com.unleash/mdm" -s rules 2>/dev/null \
      && echo "  Unleash MDM anchor: active" \
      || echo "  Unleash MDM anchor: not loaded"
    pfctl -a "com.unleash.selective" -s rules 2>/dev/null \
      && echo "  Unleash selective anchor: active" \
      || echo "  Unleash selective anchor: not loaded"
  fi
  echo ""

  step "Persistence"
  [ -f "/Library/LaunchDaemons/com.unleash.heal.plist" ] \
    && echo "  heal LaunchDaemon: installed" \
    || echo "  heal LaunchDaemon: not installed"
  [ -f "/Library/LaunchDaemons/com.unleash.monitor.plist" ] \
    && echo "  monitor LaunchDaemon: installed" \
    || echo "  monitor LaunchDaemon: not installed"
  [ -f "/tmp/unleash-monitor.pid" ] \
    && echo "  monitor process: running" \
    || echo "  monitor process: not running"
  echo ""

  step "Recent Events"
  for logfile in /var/log/unleash-monitor.log /var/log/unleash-heal.log; do
    if [ -f "$logfile" ] && [ -s "$logfile" ]; then
      echo "  From $(basename "$logfile"):"
      tail -3 "$logfile" | sed 's/^/    /'
    fi
  done
  echo ""

  step "Hosts Block"
  if grep -q "iprofiles.apple.com" /private/etc/hosts 2>/dev/null; then
    local blocked
    blocked=$(grep -c "0.0.0.0" /private/etc/hosts 2>/dev/null || echo 0)
    echo "  $blocked domain(s) blocked in /etc/hosts"
  else
    echo "  No block entries found"
  fi
  echo ""

  step "Running MDM Processes"
  local procs
  procs=$(ps aux 2>/dev/null | grep -iE "mdm|managedclient|activation" | grep -v grep || true)
  if [ -n "$procs" ]; then
    echo "$procs" | awk '{print "  " $11 " (PID " $2 ")"}'
  else
    echo "  None"
  fi
}

generate_report_json() {
  local report=""
  report="${report}{\n"

  report="${report}  \"version\": \"$VERSION\",\n"
  report="${report}  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\",\n"

  local enroll_state="unknown"
  if command -v profiles &>/dev/null; then
    enroll_state=$(sudo profiles status -type enrollment 2>/dev/null | head -1 | xargs || echo "unknown")
  fi
  enroll_state="${enroll_state//\"/\\\"}"
  report="${report}  \"enrollment_state\": \"${enroll_state}\",\n"

  local has_dep="false"
  if [ -f "/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" ]; then
    has_dep="true"
  fi
  report="${report}  \"dep_record_found\": $has_dep,\n"

  local profile_count=0
  if command -v profiles &>/dev/null; then
    profile_count=$(sudo profiles -C -output=xml 2>/dev/null | grep -c "ProfileDisplayName" || echo 0)
  fi
  report="${report}  \"installed_profiles\": $profile_count,\n"

  local heal_installed="false"
  [ -f "/Library/LaunchDaemons/com.unleash.heal.plist" ] && heal_installed="true"
  local monitor_installed="false"
  [ -f "/Library/LaunchDaemons/com.unleash.monitor.plist" ] && monitor_installed="true"
  local monitor_running="false"
  [ -f "/tmp/unleash-monitor.pid" ] && monitor_running="true"
  report="${report}  \"persistence\": {\n"
  report="${report}    \"heal_launchdaemon\": $heal_installed,\n"
  report="${report}    \"monitor_launchdaemon\": $monitor_installed,\n"
  report="${report}    \"monitor_running\": $monitor_running\n"
  report="${report}  },\n"

  local fw_active="false"
  if command -v pfctl &>/dev/null && pfctl -a "com.unleash/mdm" -s rules 2>/dev/null | grep -q "block"; then
    fw_active="true"
  fi
  local selective_active="false"
  if command -v pfctl &>/dev/null && pfctl -a "com.unleash.selective" -s rules 2>/dev/null | grep -q "block"; then
    selective_active="true"
  fi
  report="${report}  \"firewall\": {\n"
  report="${report}    \"mdm_block_active\": $fw_active,\n"
  report="${report}    \"selective_block_active\": $selective_active\n"
  report="${report}  },\n"

  local hosts_blocked=0
  hosts_blocked=$(grep -c "0.0.0.0" /private/etc/hosts 2>/dev/null || echo 0)
  report="${report}  \"hosts_blocked\": $hosts_blocked\n"

  report="${report}}"

  echo -e "$report"
}
