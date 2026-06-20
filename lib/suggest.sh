
cmd_suggest() {
  header "unleash suggest — Risk-Based Recommendations"

  local score=0
  local recommendations=""

  step "Analyzing system state..."

  if is_recovery; then
    info "System is in Recovery mode"
    recommendations="$recommendations\n  - Run 'bypass' to create admin user + suppress MDM"
    recommendations="$recommendations\n  - Run 'suppress' to silence enrollment (no user)"
    recommendations="$recommendations\n  - Run 'check' for pre-format safety report"
  else
    info "System is booted normally"
    recommendations="$recommendations\n  - Run 'sudo ./unleash heal' to check MDM state"
    recommendations="$recommendations\n  - Run 'sudo ./unleash audit' for deep scan"
  fi

  local cfg_dir="/private/var/db/ConfigurationProfiles/Settings"
  if [ -d "$cfg_dir" ]; then
    if [ -f "$cfg_dir/.cloudConfigRecordFound" ]; then
      echo -e "${YEL}⚠ DEP record still present${NC}"
      score=$((score + 10))
      recommendations="$recommendations\n  - Run 'suppress' to clear DEP markers"
    fi
  fi

  local hosts="/etc/hosts"
  if [ -f "$hosts" ] && grep -q "mdmenrollment.apple.com" "$hosts" 2>/dev/null; then
    echo -e "${GRN}✓ MDM domains blocked${NC}"
  else
    echo -e "${YEL}⚠ MDM domains not blocked${NC}"
    score=$((score + 5))
    recommendations="$recommendations\n  - Run 'sudo ./unleash firewall' for pf-level block"
  fi

  if command -v pfctl &>/dev/null; then
    if pfctl -a "com.unleash/mdm" -s rules 2>/dev/null | grep -q "block"; then
      echo -e "${GRN}✓ pf firewall active${NC}"
    fi
  fi

  detect_migration_assistant
  local ma_result=$?
  if [ "$ma_result" -ne 0 ]; then
    score=$((score + 8))
    recommendations="$recommendations\n  - Run 'sudo ./unleash harden' to clean user artifacts"
  fi

  detect_configurator_enrollment
  local cfg_result=$?
  if [ "$cfg_result" -ne 0 ]; then
    score=$((score + 15))
    recommendations="$recommendations\n  - Run 'bypass' from Recovery to clear ASM enrollment"
  fi

  echo ""
  info "Risk Score: $score"
  if [ "$score" -eq 0 ]; then
    echo -e "${GRN}✓ System is clean${NC}"
  elif [ "$score" -lt 10 ]; then
    echo -e "${YEL}⚠ Low risk${NC}"
  elif [ "$score" -lt 20 ]; then
    echo -e "${YEL}⚠ Medium risk${NC}"
  else
    echo -e "${RED}✗ High risk${NC}"
  fi

  echo ""
  info "Recommendations:"
  echo -e "$recommendations" | sed '/^$/d'
}
