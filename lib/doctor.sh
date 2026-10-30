_network_diagnostics() {
  header "Network Diagnostics"
  local version=unavailable build=unavailable
  if command -v sw_vers &>/dev/null; then
    version=$(sw_vers -productVersion 2>/dev/null) || version=unavailable
    build=$(sw_vers -buildVersion 2>/dev/null) || build=unavailable
  fi
  printf 'macOS: %s (build %s)\n' "$version" "$build"
  case "$version" in 27.*) warn "macOS 27 hardware compatibility remains unverified (issue #22)." ;; esac
  local interface ports
  if ! command -v networksetup >/dev/null; then
    warn "Wi-Fi diagnostics unavailable: networksetup is missing."
    return 1
  fi
  if ! ports=$(networksetup -listallhardwareports 2>/dev/null); then
    warn "Could not query Wi-Fi hardware ports."
    return 1
  fi
  interface=$(printf '%s\n' "$ports" | awk '
    /Hardware Port:/ { wifi=($0 ~ /: (Wi-Fi|AirPort)$/); next }
    wifi && /^[[:space:]]*Device:/ { print $2; exit }
  ' || true)
  if [ -z "$interface" ]; then
    info "No Wi-Fi hardware port reported."
    return 0
  fi
  local power status details ipv4
  if ! power=$(networksetup -getairportpower "$interface" 2>/dev/null); then
    warn "Could not query Wi-Fi power."
    return 1
  fi
  if ! details=$(ifconfig "$interface" 2>/dev/null); then
    warn "Could not query Wi-Fi link state."
    return 1
  fi
  case "$power" in *': On') power=on ;; *': Off') power=off ;; *) power=unavailable ;; esac
  status=$(printf '%s\n' "$details" | awk '/^[[:space:]]*status:/ {print $2; exit}' || true)
  ipv4=$(printf '%s\n' "$details" | awk '
    /^[[:space:]]*inet / {
      if ($2 ~ /^169[.]254[.]/) { state="link-local"; next }
      if ($2 != "0.0.0.0") { state="configured"; exit }
    }
    END { print (state ? state : "none") }
  ')
  printf 'Wi-Fi interface: %s\nWi-Fi power: %s\nLink status: %s\nWi-Fi IPv4: %s\n' "$interface" "$power" "${status:-unavailable}" "$ipv4"
}

run_doctor() {
  if [ "${1:-}" = --network ]; then _network_diagnostics; return; fi
  header "Unleash Doctor — Pre-Flight Check"

  local errors=0 warnings=0

  begin "Script location"
  local script_dir="${SCRIPT_DIR:-}"
  if [ -n "$script_dir" ] && [ -d "$script_dir" ]; then
    end_ok; echo "     $script_dir"
  else
    end_fail; errors=$((errors + 1))
  fi

  begin "Library files"
  local missing=0
  if [ "${STANDALONE_BUILD:-false}" = true ]; then
    local core
    for core in log resolve_data_volume validate_username create_admin_user suppress_enrollment backup_state deep_status _launchd_script_path heal_suppress install_pf_mdm_block harden_live_os install_selective_block run_preformat_check monitor_mdm show_history; do
      declare -F "$core" >/dev/null || missing=$((missing + 1))
    done
  else
    local lib_dir="${LIB_DIR:-}"
    for _lib in colors detect validate dscl suppress backup status launchd heal firewall harden whitelist check monitor history; do
      [ -n "$lib_dir" ] && [ -f "$lib_dir/$_lib.sh" ] || missing=$((missing + 1))
    done
  fi
  if [ "$missing" -eq 0 ]; then
    end_ok
    if [ "${STANDALONE_BUILD:-false}" = true ]; then echo "     Embedded core modules loaded";
    else echo "     Core library files available"; fi
  else
    end_fail; echo "     $missing module(s) missing"; errors=$((errors + 1))
  fi

  begin "Root privileges"
  if is_root; then
    end_ok
  else
    end_fail; echo "     Run with sudo for full checks"
    warnings=$((warnings + 1))
  fi

  begin "Recovery mode"
  if is_recovery; then
    end_ok; echo "     Full bypass available"
  else
    end_fail; echo "     Limited to booted-system commands"
    warnings=$((warnings + 1))
  fi

  begin "Disk space (Data volume)"
  local avail
  avail=$(df / 2>/dev/null | awk 'NR>1 {print $4; exit}')
  if [ -n "$avail" ] && [ "$avail" -gt 1048576 ]; then
    end_ok; echo "     $(echo "$avail" | awk '{printf "%.0f MB", $1/1024}') free"
  elif [ -n "$avail" ]; then
    end_fail; echo "     Low disk space"; warnings=$((warnings + 1))
  else
    end_fail; echo "     Cannot determine"; errors=$((errors + 1))
  fi

  begin "Internet access"
  if command -v curl &>/dev/null && curl -s --max-time 3 https://github.com >/dev/null 2>&1; then
    end_ok; echo "     Online"
  else
    end_fail; echo "     Offline (expected in Recovery)"
  fi

  begin "pfctl available"
  if command -v pfctl &>/dev/null; then
    end_ok
  else
    end_fail; echo "     Firewall commands unavailable"
  fi

  begin "profiles command"
  if command -v profiles &>/dev/null; then
    end_ok
  else
    end_fail; echo "     Audit/harden commands limited"
  fi

  begin "launchctl available"
  if command -v launchctl &>/dev/null; then
    end_ok
  else
    end_fail; echo "     Persistence commands unavailable"
  fi

  begin "Third-party firewall"
  local tp_found=""
  [ -d "/Applications/Little Snitch.app" ] && tp_found="Little Snitch"
  [ -d "/Applications/LuLu.app" ] && tp_found="${tp_found:+$tp_found, }LuLu"
  [ -f "/Library/Extensions/LittleSnitch.kext" ] && tp_found="${tp_found:+$tp_found, }Little Snitch (kext)"
  [ -d "/Applications/Radio Silence.app" ] && tp_found="${tp_found:+$tp_found, }Radio Silence"
  [ -d "/Applications/Vallum.app" ] && tp_found="${tp_found:+$tp_found, }Vallum"
  if [ -n "$tp_found" ]; then
    end_ok; echo "     $tp_found"
  else
    end_fail; echo "     None detected"
  fi

  echo ""
  step "Persistence status"
  if [ -f "/Library/LaunchDaemons/com.unleash.heal.plist" ]; then
    echo "     heal  LaunchDaemon: installed"
  else
    echo "     heal  LaunchDaemon: not installed"
  fi
  if [ -f "/Library/LaunchDaemons/com.unleash.monitor.plist" ]; then
    echo "     monitor LaunchDaemon: installed"
  else
    echo "     monitor LaunchDaemon: not installed"
  fi
  if [ -f "/etc/pf.anchors/com.unleash/mdm" ]; then
    echo "     pf firewall anchor: installed"
  else
    echo "     pf firewall anchor: not installed"
  fi
  if [ -f "/etc/pf.anchors/com.unleash.selective" ]; then
    echo "     pf selective anchor: installed"
  else
    echo "     pf selective anchor: not installed"
  fi

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
  if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    echo -e "${CYAN}║${NC}  ${GRN}All checks passed${NC}                       ${CYAN}║${NC}"
  elif [ "$errors" -eq 0 ]; then
    echo -e "${CYAN}║${NC}  ${YEL}Passed with $warnings warning(s)${NC}               ${CYAN}║${NC}"
  else
    echo -e "${CYAN}║${NC}  ${RED}$errors error(s), $warnings warning(s)${NC}              ${CYAN}║${NC}"
  fi
  echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
}
