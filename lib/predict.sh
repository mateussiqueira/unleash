
cmd_predict() {
  header "unleash predict — Serial Number Lookup"

  local serial=""
  serial=$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | grep -i "IOPlatformSerialNumber" | awk -F'"' '{print $4}' || echo "")

  if [ -z "$serial" ]; then
    serial="${1:-}"
  fi
  if [ -z "$serial" ]; then
    read -p "Enter serial number (or press Enter to skip): " serial
  fi
  if [ -z "$serial" ]; then
    info "No serial provided. Run: ./unleash predict <serial>"
    return 0
  fi

  step "Looking up: $serial"

  local serial_prefix
  serial_prefix=$(echo "$serial" | head -c 4)

  info "Serial prefix: $serial_prefix"

  local known_orgs
  known_orgs=$(cat << 'ORGS'
F5G:Apple Internal
C0D:JAMF Managed
C7G:JAMF Managed
FVF:JAMF Managed
H4C:School District Managed
VMW:VMware Workspace ONE
M5K:Addigy Managed
W4P:Kandji Managed
ORGS)

  local match
  match=$(echo "$known_orgs" | grep "^$serial_prefix:" || true)

  if [ -n "$match" ]; then
    local org_name
    org_name=$(echo "$match" | cut -d: -f2)
    echo -e "${YEL}⚠ Predicted enrollment: $org_name${NC}"
    info "This serial prefix is commonly associated with $org_name-managed devices."
    info "Remediation: sudo ./unleash remediate"
  else
    info "No known association for this serial prefix."
    info "The device may be from a smaller org or not organizationally enrolled."
  fi

  local check_url="https://billing.c.apple.com/check?sn=${serial}"
  info "For definitive ownership: https://checkcoverage.apple.com"
}
