
harden_live_os() {
	step "Killing running MDM processes..."
	for p in ManagedClient mdmclient activationd; do
		if pkill -f "$p" 2>/dev/null; then
			success "Killed $p"
		else
			info "$p not running"
		fi
	done

	step "Removing residual MDM profiles..."
	if command -v profiles &>/dev/null; then
		local installed
		installed=$(profiles -C -output=xml 2>/dev/null | grep -c "ProfileDisplayName" || true)
		if [ "$installed" -gt 0 ]; then
			sudo profiles -D -F 2>/dev/null && success "Forced profile removal" \
				|| warn "Profile removal failed"
		else
			info "No installed profiles to remove"
		fi
	else
		warn "profiles command not available"
	fi

	step "Cleaning user LaunchAgents..."
	local home
	for home in /Users/*/; do
		[ -d "$home/Library/LaunchAgents" ] || continue
		local cleaned=0
		for agent in "$home/Library/LaunchAgents/"*; do
			[ -f "$agent" ] || continue
			if grep -qiE "(mdm|enrollment|managedclient|depnotify)" "$agent" 2>/dev/null; then
				rm -f "$agent"
				cleaned=$((cleaned + 1))
			fi
		done
		[ "$cleaned" -gt 0 ] && success "$(basename "$home"): removed $cleaned agent(s)" \
			|| info "$(basename "$home"): clean"
	done

	step "Flushing DNS cache..."
	if command -v dscacheutil &>/dev/null; then
		sudo dscacheutil -flushcache && success "DNS cache flushed"
	fi
	if command -v killall &>/dev/null; then
		sudo killall -HUP mDNSResponder 2>/dev/null && success "mDNSResponder restarted" || true
	fi

	step "Checking for MDM keychain items..."
	if command -v security &>/dev/null; then
		local identities
		identities=$(sudo security find-identity -p basic 2>/dev/null | grep -ci mdm || true)
		if [ "$identities" -gt 0 ]; then
			warn "$identities MDM-related identity(ies) found in keychain"
			warn "Manual review recommended: security find-identity -p basic | grep -i mdm"
		else
			info "No MDM identities found in keychain"
		fi
	else
		warn "security command not available"
	fi

	step "Checking for JAMF/Intune/Workspace ONE agents..."
	for agent_bin in /usr/local/bin/jamf /usr/local/bin/intune /opt/cisco/anyconnect/bin/*; do
		if [ -f "$agent_bin" ]; then
			warn "MDM agent binary found: $agent_bin"
		fi
	done

	step "Disabling iCloud Private Relay (DoH source)..."
	if command -v defaults &>/dev/null; then
		sudo defaults write /Library/Preferences/com.apple.networkextensions.plist PrivateRelayEnabled -bool false 2>/dev/null \
			&& success "Private Relay disabled" \
			|| info "Private Relay not configurable (expected on some configs)"
	fi

	echo ""
	echo -e "${GRN}============================================${NC}"
	echo -e "${GRN}      Live-OS Hardening Complete             ${NC}"
	echo -e "${GRN}============================================${NC}"
	echo ""
	echo -e "${YEL}Reboot recommended to verify all changes.${NC}"
	echo -e "${YEL}For per-app blocking: install Little Snitch or LuLu.${NC}"
}

harden_status() {
	step "System extension status..."
	if command -v systemextensionsctl &>/dev/null; then
		systemextensionsctl list 2>/dev/null | head -20 || true
	else
		info "systemextensionsctl not available"
	fi

	step "MDM-related LaunchDaemons loaded..."
	launchctl list 2>/dev/null | grep -iE "mdm|managed|enrollment|activation" || info "None loaded"

	step "Running MDM processes..."
	ps aux 2>/dev/null | grep -iE "mdm|managedclient|activation" | grep -v grep || info "None running"
}
