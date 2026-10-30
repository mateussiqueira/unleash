
FIREWALL_ANCHOR="com.unleash/mdm"
FIREWALL_CONF="/etc/pf.conf"
FIREWALL_ANCHOR_DIR="/etc/pf.anchors"

pf_backup_anchor() {
	local root="$1"
	local anchor_file="${root}${FIREWALL_ANCHOR_DIR}/${FIREWALL_ANCHOR}"
	[ ! -f "$anchor_file" ] && return 0
	local backup
	backup="${anchor_file}.backup.$(date +%s)"
	cp "$anchor_file" "$backup" && info "Backed up pf anchor: $backup"
}

pf_backup_conf() {
	local root="$1"
	local pf_conf="${root}${FIREWALL_CONF}"
	[ ! -f "$pf_conf" ] && return 0
	local backup
	backup="${pf_conf}.backup.$(date +%s)"
	cp "$pf_conf" "$backup" && info "Backed up pf.conf: $backup"
}

install_pf_mdm_block() {
	local data_mount="$1"
	local root=""
	[ -n "$data_mount" ] && root="$data_mount"

	step "Installing pf anchor for MDM IP block..."
	pf_backup_conf "$root"

	local anchor_dir="${root}${FIREWALL_ANCHOR_DIR}"
	local anchor_file="${anchor_dir}/${FIREWALL_ANCHOR}"

	pf_backup_anchor "$root"
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
			printf '\n%s\n%s\n%s\n' "# Added by unleash — MDM block" "$anchor_line" "$load_line" >> "$pf_conf"
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
		if pfctl -e -f "$pf_conf" 2>/dev/null; then
			success "pf enabled and rules loaded"
		else
			warn "pfctl failed — try: sudo pfctl -e -f $pf_conf"
		fi
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
		pf_backup_anchor "$root"
		rm -f "$anchor_file"
		success "Anchor file removed"
	fi

	local pf_conf="${root}${FIREWALL_CONF}"
	if [ -f "$pf_conf" ]; then
		local tmp_conf
		tmp_conf=$(mktemp "${pf_conf}.XXXXXX") || return 1
		if ! cp -p "$pf_conf" "$tmp_conf" \
			|| ! sed '/# Added by unleash/d; /com\.unleash/d' "$pf_conf" > "$tmp_conf" \
			|| ! mv "$tmp_conf" "$pf_conf"; then
			rm -f "$tmp_conf"
			return 1
		fi
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
		if pfctl -a "$FIREWALL_ANCHOR" -s rules 2>/dev/null; then
			info "Unleash MDM anchor rules:"
		else
			info "No Unleash MDM anchor loaded"
		fi
	else
		warn "pfctl not available"
	fi
}
