detect_migration_assistant() {
  local data_mount="${1:-}"

  header "Migration Assistant Check"

  local homes=()
  if [ -n "$data_mount" ] && [ -d "$data_mount/Users" ]; then
    for h in "$data_mount/Users/"*/; do
      homes+=("$h")
    done
  elif [ -d "/Users" ]; then
    for h in /Users/*/; do
      homes+=("$h")
    done
  fi

  local ma_indicators=0
  local details=""

  for home in "${homes[@]}"; do
    local user
    user=$(basename "$home")
    [ "$user" = "Guest" ] || [ "$user" = "Shared" ] && continue
    [ -d "$home/Library" ] || continue

    local user_agents="$home/Library/LaunchAgents"
    if [ -d "$user_agents" ]; then
      local found
      found=$(ls "$user_agents" 2>/dev/null | grep -ciE "mdm|enrollment|managed" || true)
      if [ "$found" -gt 0 ]; then
        ma_indicators=$((ma_indicators + found))
        details="$details  $user: $found MDM LaunchAgent(s)\n"
      fi
    fi

    local prefs="$home/Library/Preferences"
    if [ -d "$prefs" ]; then
      local mdm_prefs
      mdm_prefs=$(ls "$prefs"/com.apple.mdm* "$prefs"/com.apple.ManagedClient* 2>/dev/null | head -3 || true)
      if [ -n "$mdm_prefs" ]; then
        ma_indicators=$((ma_indicators + 1))
        details="$details  $user: MDM preference files\n"
      fi
    fi

    local support="$home/Library/Application Support/com.apple.ManagedClient"
    if [ -d "$support" ]; then
      ma_indicators=$((ma_indicators + 1))
      details="$details  $user: ManagedClient Application Support\n"
    fi
  done

  if [ "$ma_indicators" -gt 0 ]; then
    echo -e "${YEL}⚠ Migration Assistant artifacts detected:${NC}"
    echo -e "$details" | sed '/^$/d'
    echo ""
    echo -e "${YEL}These user-level artifacts can re-enable MDM on every login.${NC}"
    echo -e "${YEL}Fix: run 'sudo ./unleash harden' or './unleash suppress' from Recovery.${NC}"
    return 1
  else
    echo -e "${GRN}✓ No Migration Assistant artifacts found${NC}"
    return 0
  fi
}
