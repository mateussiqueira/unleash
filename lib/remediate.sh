
CMD_SUGGEST=""

known_orgs() {
  cat << 'ORGS'
# Known MDM org identifiers and their remediation quirks
# Format: org_id:description:extra_block_domains
apple:Apple Internal:apple.com
jamf:JAMF Pro Managed:jamfcloud.com
mosyle:Mobile Device Management:mosyle.com
addigy:Remote Management:addigy.com
kandji:Device Management:kandji.io
vmware:Workspace ONE:air-watch.com
ORGS
}

cmd_remediate() {
  header "unleash remediate — Per-Org MDM Cleanup"

  local org="${1:-auto}"

  if [ "$org" = "auto" ] || [ "$org" = "" ]; then
    step "Detecting MDM organization..."
    local detected=""
    if [ -f "/Library/Profiles" ]; then
      detected=$(plutil -p "/Library/Profiles" 2>/dev/null | grep -iE "jamf|mosyle|addigy|kandji|vmware" | head -1 || true)
    fi
    if command -v profiles &>/dev/null; then
      local profile_info
      profile_info=$(sudo profiles -P 2>/dev/null || true)
      for org_line in $(known_orgs | grep -v "^#"); do
        local org_id
        local org_desc
        org_id=$(echo "$org_line" | cut -d: -f1)
        org_desc=$(echo "$org_line" | cut -d: -f2)
        if echo "$profile_info" | grep -qi "$org_desc"; then
          detected="$org_id"
          info "Detected: $org_desc"
          break
        fi
      done
    fi
    if [ -z "$detected" ]; then
      detected="generic"
      info "No specific org detected, using generic cleanup"
    fi
    org="$detected"
  fi

  step "Applying $org-specific remediation..."

  local extra_domains=""
  extra_domains=$(known_orgs | grep "^$org:" | cut -d: -f3 || true)

  local hosts_file="/etc/hosts"
  if [ -n "$extra_domains" ] && [ -f "$hosts_file" ]; then
    for domain in $(echo "$extra_domains" | tr ',' ' '); do
      if ! grep -q "$domain" "$hosts_file" 2>/dev/null; then
        echo "0.0.0.0 $domain" >> "$hosts_file"
        info "Blocked: $domain"
      fi
    done
  fi

  info "Running harden..."
  harden_live_os

  info "Running heal..."
  heal_suppress ""

  success "Remediation complete for $org"
  info "If MDM returns, open an issue with the org name."
}
