generate_report() {
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
