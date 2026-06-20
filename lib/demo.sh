run_demo() {
  header "Unleash Demo — Simulated MDM Bypass"

  local demo_dir
  demo_dir=$(mktemp -d)
  mkdir -p "$demo_dir/private/etc"
  mkdir -p "$demo_dir/private/var/db/ConfigurationProfiles/Settings"
  mkdir -p "$demo_dir/private/var/db/com.apple.xpc.launchd"
  mkdir -p "$demo_dir/Users/demo/Library/Preferences"
  mkdir -p "$demo_dir/Users/demo/Library/Application Support"

  touch "$demo_dir/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
  touch "$demo_dir/Users/demo/Library/Preferences/com.apple.mdm.plist"

  echo ""
  step "1. Simulating pre-bypass MDM state"
  echo "     DEP record:      ${RED}PRESENT${NC}"
  echo "     Hosts block:     ${RED}ABSENT${NC}"
  echo "     Daemon override: ${RED}ABSENT${NC}"
  echo "     User artifacts:  ${RED}PRESENT${NC}"
  sleep 1

  echo ""
  step "2. Running suppress_enrollment..."
  DRY_RUN=false
  suppress_enrollment "$demo_dir" 2>/dev/null || true
  sleep 1

  echo ""
  step "3. Verifying post-bypass state"
  local clean=true
  if [ -f "$demo_dir/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" ]; then
    echo "     DEP record:      ${RED}STILL PRESENT (bug)${NC}"
    clean=false
  else
    echo "     DEP record:      ${GRN}CLEARED${NC}"
  fi
  if grep -q "iprofiles.apple.com" "$demo_dir/private/etc/hosts" 2>/dev/null; then
    echo "     Hosts block:     ${GRN}ACTIVE${NC}"
  else
    echo "     Hosts block:     ${RED}ABSENT (bug)${NC}"
    clean=false
  fi
  if [ -f "$demo_dir/Users/demo/Library/Preferences/com.apple.mdm.plist" ]; then
    echo "     User artifacts:  ${RED}STILL PRESENT (bug)${NC}"
    clean=false
  else
    echo "     User artifacts:  ${GRN}CLEANED${NC}"
  fi

  echo ""
  step "4. Simulating macOS update (re-enabling daemons)"
  rm -f "$demo_dir/private/var/db/com.apple.xpc.launchd/disabled.plist"
  echo "     Daemon override: ${RED}RESET (simulating update)${NC}"
  sleep 1

  echo ""
  step "5. Running heal — detecting and fixing..."
  heal_suppress "$demo_dir" 2>/dev/null || true
  sleep 1

  if [ -f "$demo_dir/private/var/db/com.apple.xpc.launchd/disabled.plist" ]; then
    echo "     Daemon override: ${GRN}RESTORED${NC}"
  fi

  echo ""
  step "6. Summary"
  if [ "$clean" = true ]; then
    echo -e "   ${GRN}✓ Demo completed successfully${NC}"
  else
    echo -e "   ${YEL}⚠ Demo completed with warnings${NC}"
  fi
  echo "   Simulated environment: $demo_dir"
  echo ""
  info "This is a simulated run. No real system was modified."
  info "Run 'rm -rf $demo_dir' to clean up."

  echo ""
  echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  ${GRN}Demo Complete${NC}                                         ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  Commands used: suppress, heal                    ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  Try: ${YEL}sudo ./unleash doctor${NC}  for real diagnostics       ${CYAN}║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
}
