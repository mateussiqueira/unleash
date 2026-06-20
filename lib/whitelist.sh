MDM_BLOCKLIST="mdmenrollment.apple.com deviceenrollment.apple.com iprofiles.apple.com"

install_selective_block() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"

  step "Installing selective pf rules (block MDM only, allow Apple services)..."

  local anchor_dir="${root}/etc/pf.anchors"
  local anchor_file="${anchor_dir}/com.unleash.selective"
  mkdir -p "$anchor_dir"

  > "$anchor_file"

  for d in $MDM_BLOCKLIST; do
    for ip in $(host -t a "$d" 2>/dev/null | awk '/has address/{print $NF}'); do
      echo "block drop out proto {tcp,udp} to {$ip}" >> "$anchor_file"
    done
    for ip in $(host -t aaaa "$d" 2>/dev/null | awk '/has IPv6 addr/{print $NF}'); do
      echo "block drop out proto {tcp,udp} to {$ip}" >> "$anchor_file"
    done
  done

  chmod 644 "$anchor_file"
  success "Selective anchor written: $anchor_file"

  local pf_conf="${root}/etc/pf.conf"
  local anchor_line="anchor \"com.unleash.selective\""
  local load_line="load anchor \"com.unleash.selective\" from \"${anchor_file}\""

  if [ -f "$pf_conf" ]; then
    if grep -q "com.unleash.selective" "$pf_conf" 2>/dev/null; then
      info "pf.conf already has selective anchor"
    else
      echo "" >> "$pf_conf"
      echo "# Added by unleash — selective MDM block (iCloud-safe)" >> "$pf_conf"
      echo "$anchor_line" >> "$pf_conf"
      echo "$load_line" >> "$pf_conf"
      success "pf.conf updated with selective rules"
    fi
  else
    cat > "$pf_conf" <<- EOF
scrub-anchor "com.apple/*"
nat-anchor "com.apple/*"
rdr-anchor "com.apple/*"
dummynet-anchor "com.apple/*"
fwd-anchor "com.apple/*"
anchor "com.apple/*"
load anchor "com.apple" from "/etc/pf.anchors/com.apple"
# Added by unleash — selective MDM block (iCloud-safe)
${anchor_line}
${load_line}
EOF
    success "pf.conf created"
  fi

  if command -v pfctl &>/dev/null; then
    pfctl -e -f "$pf_conf" 2>/dev/null && success "pf rules loaded (iCloud should work)" \
      || warn "pfctl failed"
  fi
}

restore_hosts_based_block() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"
  local hosts="${root}/private/etc/hosts"

  if [ -f "$hosts" ] && grep -q "Added by unleash" "$hosts" 2>/dev/null; then
    info "unleash hosts entries intact"
  fi
}
