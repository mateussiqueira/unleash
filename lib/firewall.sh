# unleash/lib/firewall.sh — pf firewall management for MDM blocking

FIREWALL_ANCHOR="com.unleash/mdm"
FIREWALL_CONF="/etc/pf.conf"
FIREWALL_ANCHOR_DIR="/etc/pf.anchors"

install_pf_mdm_block() {
	local data_mount="$1"
	local root=""
	[ -n "$data_mount" ] && root="$data_mount"

	step "Installing pf anchor for MDM IP block..."

	local anchor_dir="${root}${FIREWALL_ANCHOR_DIR}"
	local anchor_file="${anchor_dir}/${FIREWALL_ANCHOR}"

	mkdir -p "$anchor_dir"

	cat > "$anchor_file" << 'ANCHOR'
# Unleash MDM block — Apple MDM infrastructure IP ranges
# These ranges host deviceenrollment.apple.com, mdmenrollment.apple.com, etc.
# Blocking at pf level is immune to DNS-over-HTTPS bypass.
block drop out proto {tcp,udp} to {17.0.0.0/8}
block drop out proto {tcp,udp} to {17.128.0.0/10}
ANCHOR
	chmod 644 "$anchor_file"
	success "Anchor written: $anchor_file"

	local pf_conf="${root}${FIREWALL_CONF}"
	local anchor_line="anchor \"${FIREWALL_ANCHOR}\""
	local load_line="load anchor \"${FIREWALL_ANCHOR}\" from \"${anchor_file}\""

	if [ -f "$pf_conf" ]; then
		if grep -q "com.unleash" "$pf_conf" 2>/dev/null; then
			info "pf.conf already has Unleash anchor"
		else
			echo "" >> "$pf_conf"
			echo "# Added by unleash — MDM block" >> "$pf_conf"
			echo "$anchor_line" >> "$pf_conf"
			echo "$load_line" >> "$pf_conf"
			success "pf.conf updated"
		fi
	else
		cat > "$pf_conf" <<- EOF
		# pf.conf — restored by unleash
		#
		# Default macOS pf.conf
		scrub-anchor "com.apple/*"
		nat-anchor "com.apple/*"
		rdr-anchor "com.apple/*"
		dummynet-anchor "com.apple/*"
		fwd-anchor "com.apple/*"
		anchor "com.apple/*"
		load anchor "com.apple" from "/etc/pf.anchors/com.apple"

		# Added by unleash — MDM block
		${anchor_line}
		${load_line}
		EOF
		success "pf.conf created with Unleash anchor"
	fi

	step "Loading pf rules..."
	if command -v pfctl &>/dev/null; then
		pfctl -e -f "$pf_conf" 2>/dev/null && success "pf enabled and rules loaded" \
			|| warn "pfctl failed — try: sudo pfctl -e -f $pf_conf"
	else
		warn "pfctl not available"
	fi

	warn "This blocks ALL Apple services (iCloud, App Store, updates)."
	warn "For selective blocking, use Little Snitch or LuLu instead."
}

remove_pf_mdm_block() {
	local data_mount="$1"
	local root=""
	[ -n "$data_mount" ] && root="$data_mount"

	step "Removing Unleash pf anchor..."

	local anchor_file="${root}${FIREWALL_ANCHOR_DIR}/${FIREWALL_ANCHOR}"
	if [ -f "$anchor_file" ]; then
		rm -f "$anchor_file"
		success "Anchor file removed"
	fi

	local pf_conf="${root}${FIREWALL_CONF}"
	if [ -f "$pf_conf" ]; then
		sed -i '' '/# Added by unleash/d' "$pf_conf" 2>/dev/null || true
		sed -i '' '/com\.unleash/d' "$pf_conf" 2>/dev/null || true
		success "pf.conf cleaned"
	fi

	step "Flushing pf anchor..."
	if command -v pfctl &>/dev/null; then
		pfctl -a "$FIREWALL_ANCHOR" -F all 2>/dev/null || true
		success "pf anchor flushed"
	else
		warn "pfctl not available"
	fi
}

pf_status() {
	step "pf firewall status..."
	if command -v pfctl &>/dev/null; then
		pfctl -si 2>/dev/null | grep -E "Status|Enabled" || echo "  pf not enabled"
		echo ""
		pfctl -a "$FIREWALL_ANCHOR" -s rules 2>/dev/null \
			&& info "Unleash MDM anchor rules:" \
			|| info "No Unleash MDM anchor loaded"
	else
		warn "pfctl not available"
	fi
}
