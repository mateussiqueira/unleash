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
		matches=$(grep -iE 'iprofiles|enrollment|mdm|acmdm' "$hosts" 2>/dev/null)
		if [ -n "$matches" ]; then
			echo "$matches" | while IFS= read -r line; do
				echo -e "  ${GRN}$line${NC}"
			done
		else
			echo -e "  ${YEL}(none)${NC}"
		fi
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
