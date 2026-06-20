
cmd_init() {
  header "unleash init — Setup Wizard"

  echo "This will walk you through setting up unleash for your Mac."
  echo "Press Ctrl+C at any time to abort."
  echo ""

  local root_ok=false
  if is_root; then
    root_ok=true
  else
    warn "Not running as root. Some checks will be limited."
    echo ""
  fi

  step "Checking macOS version..."
  local osver
  osver=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
  info "macOS $osver"

  step "Checking architecture..."
  local arch
  arch=$(uname -m 2>/dev/null || echo "unknown")
  info "$arch"

  step "Checking Recovery mode..."
  if is_recovery; then
    echo -e "${GRN}✓ Recovery mode${NC}"
  else
    echo -e "${YEL}⚠ Not in Recovery${NC}"
    echo "  Some commands (bypass, suppress) require Recovery."
  fi

  echo ""

  detect_migration_assistant
  echo ""

  detect_configurator_enrollment
  echo ""

  echo -n "Enable pf firewall (blocks MDM at kernel level)? [y/N] "
  read -r ans
  if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
    if $root_ok; then
      install_pf_mdm_block ""
    else
      info "Skipping firewall (needs root). Run: sudo ./unleash firewall"
    fi
  fi

  echo ""
  echo -n "Enable MDM monitor (checks every 5 min)? [y/N] "
  read -r ans
  if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
    if $root_ok; then
      install_monitor_launchdaemon ""
    else
      info "Skipping monitor (needs root). Run: sudo ./unleash monitor-install"
    fi
  fi

  echo ""
  echo -n "Enable persistent auto-heal (on every boot)? [y/N] "
  read -r ans
  if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
    if $root_ok && ! is_recovery; then
      install_persist_launchdaemon ""
    elif is_recovery; then
      echo -e "${YEL}Run after reboot: sudo ./unleash persist${NC}"
    else
      info "Skipping persist (needs root). Run: sudo ./unleash persist"
    fi
  fi

  echo ""
  echo -n "Back up current system state? [y/N] "
  read -r ans
  if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
    local dm
    dm=$(resolve_data_volume 2>/dev/null || echo "/")
    backup_state "$dm"
  fi

  echo ""
  success "Setup complete!"
  info "Recommended next steps:"
  info "  - From Recovery: ./unleash bypass  (full bypass)"
  info "  - From Recovery: ./unleash check  (pre-format check)"
  info "  - After login:   sudo ./unleash harden"
}
