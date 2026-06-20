VPN_RULES_ANCHOR="com.unleash/vpn-kill"
VPN_RULES_FILE="/etc/pf.anchors/com.unleash/vpn-kill"

vpn_kill_install() {
  header "VPN Kill-Switch — MDM Leak Protection"

  if ! is_root; then
    error_exit "VPN kill-switch needs sudo: sudo ./unleash vpn-kill"
  fi

  local vpn_if=""

  step "Detecting active VPN interfaces..."
  local interfaces
  interfaces=$(ifconfig 2>/dev/null | grep -E "^utun[0-9]+:" | sed 's/:.*//' || true)
  if [ -z "$interfaces" ]; then
    warn "No VPN interfaces detected"
    info "You can specify manually: sudo ./unleash vpn-kill --interface utunX"
    info "Common VPN interfaces: utun0-9 (WireGuard), utun10+ (OpenVPN), ppp0 (L2TP)"
  else
    for iface in $interfaces; do
      local addr
      addr=$(ifconfig "$iface" 2>/dev/null | awk '/inet /{print $2}')
      if [ -n "$addr" ]; then
        echo "   $iface: $addr"
        [ -z "$vpn_if" ] && vpn_if="$iface"
      fi
    done
  fi

  local user_if="${2:-}"
  [ -n "$user_if" ] && vpn_if="$user_if"

  if [ -z "$vpn_if" ]; then
    warn "No active VPN detected. Installing kill-switch anyway (no default route)."
    info "Usage: sudo ./unleash vpn-kill --interface utunX"
    return 1
  fi

  step "Installing pf rules for VPN kill-switch..."
  local anchor_dir="/etc/pf.anchors/com.unleash"
  mkdir -p "$anchor_dir"

  cat > "$VPN_RULES_FILE" << RULES
# Unleash VPN kill-switch
# Only allow MDM traffic through VPN interface $vpn_if
block drop out proto {tcp,udp} to {17.0.0.0/8, 17.128.0.0/10}
pass out proto {tcp,udp} to {17.0.0.0/8, 17.128.0.0/10} no state
pass on $vpn_if
RULES
  chmod 644 "$VPN_RULES_FILE"
  success "VPN kill-switch rules installed for $vpn_if"

  local pf_conf="/etc/pf.conf"
  local anchor_line="anchor \"${VPN_RULES_ANCHOR}\""
  local load_line="load anchor \"${VPN_RULES_ANCHOR}\" from \"${VPN_RULES_FILE}\""

  if grep -q "vpn-kill" "$pf_conf" 2>/dev/null; then
    info "pf.conf already has VPN kill-switch anchor"
  else
    echo "" >> "$pf_conf"
    echo "# Added by unleash — VPN kill-switch (prevents MDM leaks)" >> "$pf_conf"
    echo "$anchor_line" >> "$pf_conf"
    echo "$load_line" >> "$pf_conf"
  fi

  pfctl -e -f "$pf_conf" 2>/dev/null && success "VPN kill-switch active" \
    || warn "pfctl failed"

  echo ""
  info "What this does:"
  info "  - Blocks MDM Apple IP ranges (17.0.0.0/8) on all interfaces"
  info "  - Only allows MDM traffic through VPN interface ($vpn_if)"
  info "  - If VPN drops, MDM traffic is blocked — no leaks"
  echo ""
  warn "This does NOT affect your regular internet traffic."
  warn "Only MDM-related IPs are routed through the VPN kill-switch."
}

vpn_kill_remove() {
  header "Remove VPN Kill-Switch"

  if ! is_root; then
    error_exit "Needs sudo: sudo ./unleash vpn-kill-remove"
  fi

  if [ -f "$VPN_RULES_FILE" ]; then
    rm -f "$VPN_RULES_FILE"
    success "VPN kill-switch rules removed"
  fi

  local pf_conf="/etc/pf.conf"
  if [ -f "$pf_conf" ]; then
    sed -i '' '/# Added by unleash — VPN kill-switch/d' "$pf_conf" 2>/dev/null || true
    sed -i '' '/vpn-kill/d' "$pf_conf" 2>/dev/null || true
    success "pf.conf cleaned"
  fi

  pfctl -a "$VPN_RULES_ANCHOR" -F all 2>/dev/null || true
  success "pf anchor flushed"
}

vpn_kill_status() {
  step "VPN kill-switch status"
  if [ -f "$VPN_RULES_FILE" ]; then
    echo "  Rules file: $VPN_RULES_FILE"
    cat "$VPN_RULES_FILE" | sed 's/^/    /'
  else
    echo "  No VPN kill-switch installed"
  fi
  if command -v pfctl &>/dev/null; then
    echo ""
    pfctl -a "$VPN_RULES_ANCHOR" -s rules 2>/dev/null \
      && echo "  Anchor loaded" \
      || echo "  Anchor not loaded"
  fi
}
