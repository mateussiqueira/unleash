# unleash/lib/status.sh — Verify and status check

check_mdm_status() {
	local data_mount="$1"
	local hosts="$data_mount/private/etc/hosts"
	local cfg="$data_mount/private/var/db/ConfigurationProfiles/Settings"
	local ldp="$data_mount/private/var/db/com.apple.xpc.launchd/disabled.plist"

	header "MDM Status Report"

	step "DEP markers ($cfg)"
	if [ -d "$cfg" ]; then
		for f in \
			.cloudConfigHasActivationRecord \
			.cloudConfigRecordFound \
			.cloudConfigRecordNotFound \
			.cloudConfigProfileInstalled \
			.cloudConfigTimerCheck; do
			if [ -f "$cfg/$f" ]; then
				echo -e "  ${GRN}$f${NC} — present"
			else
				echo -e "  ${YEL}$f${NC} — absent"
			fi
		done
	else
		warn "Settings directory not found"
	fi
	echo ""

	step "Blocked domains in hosts"
	if [ -f "$hosts" ]; then
		local matches
		matches=$(grep -iE 'iprofiles|enrollment|mdm|acmdm|albert|gdmf|configuration|xp\.apple|gs\.apple|tb\.apple' "$hosts" 2>/dev/null)
		if [ -n "$matches" ]; then
			echo "$matches" | while IFS= read -r line; do
				echo -e "  ${GRN}$line${NC}"
			done
		else
			echo -e "  ${YEL}(none)${NC}"
		fi
		local count; count=$(echo "$matches" | grep -c . 2>/dev/null || echo 0)
		echo -e "  ${CYAN}Total: $count of 13 expected domains blocked${NC}"
	else
		echo -e "  ${YEL}(hosts not found)${NC}"
	fi
	echo ""

	step "Enrollment daemon status"
	if [ -f "$ldp" ]; then
		/usr/libexec/PlistBuddy -c "Print" "$ldp" 2>/dev/null || echo -e "  ${YEL}(empty/corrupt)${NC}"
	else
		echo -e "  ${YEL}(no override)${NC}"
	fi
	echo ""

	step "Profiles enrollment status"
	if command -v profiles &>/dev/null; then
		profiles status -type enrollment 2>/dev/null \
			|| echo -e "  ${YEL}Cannot check (expected in Recovery)${NC}"
	else
		echo -e "  ${YEL}'profiles' not available${NC}"
	fi
	echo ""

	step "Backup status"
	if has_backup; then
		echo -e "  ${GRN}Backup exists:${NC} $(cat "$BACKUP_DIR/timestamp")"
	else
		echo -e "  ${YEL}No backup${NC}"
	fi
	echo ""

	if [ -f "$cfg/.cloudConfigRecordFound" ]; then
		local org
		org=$(plutil -convert xml1 -o - "$cfg/.cloudConfigRecordFound" 2>/dev/null \
			| grep -iA1 OrganizationName | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
		[ -n "$org" ] && echo -e "${YEL}Active DEP record found — device assigned to: $org${NC}"
	else
		echo -e "${GRN}No active DEP record.${NC}"
	fi
}

deep_status() {
	header "Deep MDM Audit"

	step "Installed Configuration Profiles"
	if command -v profiles &>/dev/null; then
		local profile_count
		profile_count=$(sudo profiles -C -output=xml 2>/dev/null | grep -c "ProfileDisplayName" || echo 0)
		if [ "$profile_count" -gt 0 ]; then
			warn "$profile_count profile(s) installed:"
			sudo profiles -C -output=xml 2>/dev/null | grep -A1 "ProfileDisplayName" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/  - \1/'
		else
			info "No configuration profiles installed"
		fi
	else
		warn "profiles command not available"
	fi
	echo ""

	step "MDM Enrollment State"
	if command -v profiles &>/dev/null; then
		sudo profiles status -type enrollment 2>/dev/null || echo "  Cannot determine"
	fi
	echo ""

	step "MDM Identity Certificates (Keychain)"
	if command -v security &>/dev/null; then
		local mdm_certs
		mdm_certs=$(sudo security find-identity -p basic 2>/dev/null | grep -ci "mdm\|MDM\|Apple.*Push" || true)
		if [ "$mdm_certs" -gt 0 ]; then
			warn "$mdm_certs MDM-related certificate(s) found"
			sudo security find-identity -p basic 2>/dev/null | grep -i "mdm\|Apple.*Push"
		else
			info "No MDM certificates found in keychain"
		fi
	else
		warn "security command not available"
	fi
	echo ""

	step "MDM LaunchAgents (User)"
	local found=0
	for home in /Users/*/; do
		[ -d "$home/Library/LaunchAgents" ] || continue
		local user_agents
		user_agents=$(ls "$home/Library/LaunchAgents/" 2>/dev/null | grep -iE "mdm|enrollment|managed" || true)
		if [ -n "$user_agents" ]; then
			echo -e "  ${YEL}$(basename "$home"):${NC}"
			echo "$user_agents" | sed 's/^/    /'
			found=$((found + 1))
		fi
	done
	[ "$found" -eq 0 ] && info "No MDM LaunchAgents found in any user"
	echo ""

	step "MDM LaunchDaemons (System)"
	local sys_agents
	sys_agents=$(ls /Library/LaunchDaemons/ 2>/dev/null | grep -iE "mdm|enrollment|managed" || true)
	if [ -n "$sys_agents" ]; then
		echo "$sys_agents" | sed 's/^/  /'
	else
		info "No MDM LaunchDaemons found"
	fi
	echo ""

	step "Running MDM Processes"
	local procs
	procs=$(ps aux 2>/dev/null | grep -iE "mdm|managedclient|activation" | grep -v grep || true)
	if [ -n "$procs" ]; then
		echo "$procs" | awk '{print "  " $11 " (PID " $2 ")"}'
	else
		info "No MDM processes running"
	fi
	echo ""

	step "MDM Agent Binaries"
	for agent_bin in /usr/local/bin/jamf /usr/local/bin/jamfagent /opt/jamf/bin/jamf \
		/usr/local/bin/intune /usr/local/bin/microsoft-intune \
		/Applications/Jamf* /Applications/Microsoft\ Intune* /Applications/VMware\ Workspace*; do
		if [ -e "$agent_bin" ]; then
			warn "Agent binary found: $agent_bin"
		fi
	done
	info "Scan complete"
	echo ""

	step "Firewall Status"
	pf_status 2>/dev/null || info "pf firewall check skipped"

	step "Overall Assessment"
	local risk="LOW"
	[ "$(sudo profiles -C -output=xml 2>/dev/null | grep -c "ProfileDisplayName" || echo 0)" -gt 0 ] && risk="MEDIUM"
	ps aux 2>/dev/null | grep -qiE "mdm|managedclient" && risk="HIGH"
	[ -f "$cfg/.cloudConfigRecordFound" ] && risk="CRITICAL"

	case "$risk" in
		LOW) echo -e "  ${GRN}Risk: $risk — Device appears clean${NC}" ;;
		MEDIUM) echo -e "  ${YEL}Risk: $risk — Residual profiles detected${NC}" ;;
		HIGH) echo -e "  ${RED}Risk: $risk — MDM processes still running${NC}" ;;
		CRITICAL) echo -e "  ${RED}Risk: $risk — Active DEP record found${NC}" ;;
	esac
}
