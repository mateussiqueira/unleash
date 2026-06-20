detect_configurator_enrollment() {
  local data_mount="${1:-}"

  header "Apple Configurator / ASM Enrollment Check"

  local sys_dir
  if [ -n "$data_mount" ] && [ -d "$data_mount/private/var/db" ]; then
    sys_dir="$data_mount/private/var/db"
  elif [ -d "/private/var/db" ]; then
    sys_dir="/private/var/db"
  else
    warn "Cannot locate system database directory"
    return 1
  fi

  local indicators=0

  # Configurator enrollment flag
  if [ -f "$sys_dir/ConfigurationProflements/Setup/.configuratorEnrollment" ]; then
    echo -e "${YEL}⚠ Apple Configurator enrollment detected${NC}"
    indicators=$((indicators + 1))
  fi

  # Check for ASM/ABM cloud config records
  for f in "$sys_dir"/ConfigurationProfiles/Settings/.cloudConfig*; do
    [ -f "$f" ] || continue
    local name
    name=$(basename "$f")
    echo -e "${YEL}  DEP marker present: $name${NC}"
    indicators=$((indicators + 1))
  done

  # Enrollment challenge tokens
  local challenge_dir="$sys_dir/ConfigurationProflements/Setup"
  if [ -f "$challenge_dir/.configuratorEnrollment" ]; then
    echo -e "${YEL}  Configurator challenge present${NC}"
    indicators=$((indicators + 1))
  fi

  # DEP enrollment receipt
  if [ -f "$sys_dir/com.apple.DEPReceipt" ]; then
    echo -e "${YEL}  DEP receipt found${NC}"
    indicators=$((indicators + 1))
  fi

  if [ "$indicators" -eq 0 ]; then
    echo -e "${GRN}✓ No Configurator/ASM enrollment detected${NC}"
    return 0
  else
    echo ""
    echo -e "${YEL}Fix: re-run bypass from Recovery, then run 'sudo ./unleash harden'${NC}"
    return 1
  fi
}

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

    local caches="$home/Library/Caches"
    if [ -d "$caches" ]; then
      local enrollment_cache
      enrollment_cache=$(ls "$caches"/com.apple.enrollment* 2>/dev/null | head -3 || true)
      if [ -n "$enrollment_cache" ]; then
        ma_indicators=$((ma_indicators + 1))
        details="$details  $user: enrollment cache files\n"
      fi

      local mdmd_cache
      mdmd_cache=$(ls "$caches"/com.apple.mdm* 2>/dev/null | head -3 || true)
      if [ -n "$mdmd_cache" ]; then
        ma_indicators=$((ma_indicators + 1))
        details="$details  $user: MDM cache files\n"
      fi
    fi

    local keychains="$home/Library/Keychains"
    if [ -f "$keychains/OCSPCache.plist" ]; then
      local ocsp_mdm
      ocsp_mdm=$(grep -l "mdm" "$keychains/OCSPCache.plist" 2>/dev/null || true)
      if [ -n "$ocsp_mdm" ]; then
        ma_indicators=$((ma_indicators + 1))
        details="$details  $user: MDM OCSP cache\n"
      fi
    fi
  done

  if [ "$ma_indicators" -gt 0 ]; then
    echo -e "${YEL}⚠ Migration Assistant artifacts detected (severity: $ma_indicators):${NC}"
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
