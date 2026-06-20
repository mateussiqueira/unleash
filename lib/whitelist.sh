# unleash/lib/whitelist.sh — Selective Apple services whitelist

# Domains needed for iCloud, App Store, and system updates
readonly ICLOUD_DOMAINS=(
	"apple.com"
	"icloud.com"
	"icloud.apple.com"
	"setup.icloud.com"
	"gsa.apple.com"
	"appleid.apple.com"
	"idmsa.apple.com"
	"keyvalueservice.icloud.com"
	"ckdatabase.icloud.com"
	"ckdevices.icloud.com"
)

readonly APPSTORE_DOMAINS=(
	"itunes.apple.com"
	"apps.apple.com"
	"appstoreconnect.apple.com"
	"buy.itunes.apple.com"
	"sandbox.itunes.apple.com"
)

readonly UPDATES_DOMAINS=(
	"swscan.apple.com"
	"swcdn.apple.com"
	"swdist.apple.com"
	"gdmf.apple.com"
	"ns.itunes.apple.com"
)

# MDM domains that MUST remain blocked
readonly MDM_BLOCKLIST=(
	"mdmenrollment.apple.com"
	"deviceenrollment.apple.com"
	"iprofiles.apple.com"
)

# Selective pf rules: block only MDM, allow Apple services
install_selective_block() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"

  step "Installing selective pf rules (block MDM only, allow Apple services)..."

  local anchor_dir="${root}/etc/pf.anchors"
  local anchor_file="${anchor_dir}/com.unleash.selective"
  mkdir -p "$anchor_dir"

  cat > "$anchor_file" << 'ANCHOR'
# Unleash selective MDM block — blocks only MDM enrollment endpoints
# Allows iCloud, App Store, and system updates through.
ANCHOR

  local d
  for d in "${MDM_BLOCKLIST[@]}"; do
    echo "block drop out proto {tcp,udp} to {\$(host -t a \"$d\" 2>/dev/null | awk '/has address/{print \$NF}')}" >> "$anchor_file"
    echo "block drop out proto {tcp,udp} to {\$(host -t aaaa \"$d\" 2>/dev/null | awk '/has IPv6 addr/{print \$NF}')}" >> "$anchor_file"
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
# pf.conf — restored by unleash (selective mode)
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
  step "Restoring hosts-based block (leaving unleashes entries)..."

  if [ -f "$hosts" ]; then
    if grep -q "Added by unleash" "$hosts" 2>/dev/null; then
      info "unleash hosts entries intact"
    else
      info "No unleash hosts entries found"
    fi
  fi
}
