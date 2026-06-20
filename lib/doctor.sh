run_doctor() {
  header "Unleash Doctor — Pre-Flight Check"

  local errors=0 warnings=0

  begin "Script location"
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR" ]; then
    end_ok; echo "     $SCRIPT_DIR"
  else
    end_fail; errors=$((errors + 1))
  fi

  begin "Library files"
  local missing=0
  for _lib in colors detect validate dscl suppress backup status heal firewall harden whitelist check monitor history; do
    [ -f "$LIB_DIR/$_lib.sh" ] || missing=$((missing + 1))
  done
  if [ "$missing" -eq 0 ]; then
    end_ok; echo "     13/13 modules loaded"
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
  local mount_pt
  mount_pt=$(df / 2>/dev/null | awk 'NR>1 {print $NF; exit}')
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
