

PB=/usr/libexec/PlistBuddy

suppress_enrollment() {
	local data_mount="$1"

	if [ "$DRY_RUN" = true ]; then
		info "[DRY RUN] Would suppress MDM enrollment on $data_mount"
		info "[DRY RUN]   - Clear DEP markers in ConfigurationProfiles/Settings"
		info "[DRY RUN]   - Block 13+ Apple MDM domains in /etc/hosts"
		info "[DRY RUN]   - Disable 4 enrollment daemons in launchd disabled.plist"
		info "[DRY RUN]   - Clean MDM artifacts from /Users/*/Library"
		return 0
	fi

	local hosts="$data_mount/private/etc/hosts"
	local cfg="$data_mount/private/var/db/ConfigurationProfiles/Settings"
	local ldp="$data_mount/private/var/db/com.apple.xpc.launchd/disabled.plist"
	local setupdone="$data_mount/private/var/db/.AppleSetupDone"

	step "Reading DEP activation record..."
	local mdm_host="" org=""
	if [ -f "$cfg/.cloudConfigRecordFound" ]; then
		mdm_host=$(plutil -convert xml1 -o - "$cfg/.cloudConfigRecordFound" 2>/dev/null \
			| grep -ioE 'https?://[a-z0-9._-]+' | sed -E 's#https?://##' \
			| sort -u | grep -viE '(^|\.)apple\.com$' | head -1)
		org=$(plutil -convert xml1 -o - "$cfg/.cloudConfigRecordFound" 2>/dev/null \
			| grep -iA1 OrganizationName | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
		[ -n "$org" ] && info "Device assigned in ABM to: $org"
		[ -n "$mdm_host" ] && info "Org MDM host: $mdm_host"
	else
		info "No DEP activation record present."
	fi

	step "Blocking enrollment domains (Data volume hosts)..."
	[ -f "$hosts" ] || { mkdir -p "$(dirname "$hosts")"; touch "$hosts"; }
	grep -q "Added by unleash" "$hosts" 2>/dev/null || {
		echo "" >>"$hosts"
		echo "# Added by unleash — DEP enrollment block" >>"$hosts"
	}

	local domains=(
		iprofiles.apple.com
		deviceenrollment.apple.com
		mdmenrollment.apple.com
		acmdm.apple.com
		axm-adm-mdm.apple.com
		albert.apple.com
		gdmf.apple.com
		ax.init-content.apple.com
		init-content.apple.com
		configuration.apple.com
		xp.apple.com
		gs.apple.com
		tb.apple.com
		vpp.itunes.apple.com
	)
	[ -n "$mdm_host" ] && domains+=("$mdm_host")

	local d
	for d in "${domains[@]}"; do
		grep -qiE "[[:space:]]$d(\$|[[:space:]])" "$hosts" 2>/dev/null \
			&& { info "$d already blocked"; continue; }
		printf '0.0.0.0 %s\n::      %s\n' "$d" "$d" >>"$hosts"
		success "blocked $d"
	done

	step "Resetting DEP markers..."
	mkdir -p "$cfg"
	rm -f "$cfg/.cloudConfigHasActivationRecord" \
	      "$cfg/.cloudConfigRecordFound" \
	      "$cfg/.cloudConfigTimerCheck" \
	      "$cfg/.cloudConfigProfileInstalled" \
	      "$cfg/com.apple.mdm.depnag.plist" \
	      "$cfg/com.apple.mdm.prelogin.plist" 2>/dev/null
	touch "$cfg/.cloudConfigRecordNotFound"
	success "Cached record cleared; bypass markers set"

	step "Cleaning user-level MDM artifacts..."
	local home
	for home in "$data_mount/Users/"*/; do
		[ -d "$home/Library" ] || continue
		local user
		user=$(basename "$home")
		info "Cleaning: $user"
		rm -rf "$home/Library/Preferences/com.apple.mdm"* 2>/dev/null || true
		rm -rf "$home/Library/Preferences/com.apple.ManagedClient"* 2>/dev/null || true
		rm -rf "$home/Library/Application Support/com.apple.ManagedClient"* 2>/dev/null || true
		rm -rf "$home/Library/LaunchAgents/com.apple.mdm"* 2>/dev/null || true
		for agent in "$home/Library/LaunchAgents/"*; do
			[ -f "$agent" ] || continue
			if grep -qi mdm "$agent" 2>/dev/null || grep -qi enrollment "$agent" 2>/dev/null; then
				rm -f "$agent"
				info "  removed LaunchAgent: $(basename "$agent")"
			fi
		done
	done
	success "User-level MDM artifacts removed"

	step "Disabling enrollment daemons..."
	mkdir -p "$(dirname "$ldp")"
	[ -f "$ldp" ] || printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict/></plist>\n' >"$ldp"
	for label in \
		com.apple.ManagedClient.enroll \
		com.apple.ManagedClient.cloudConfiguration \
		com.apple.mdmclient.daemon.runatboot \
		com.apple.activationd; do
		$PB -c "Add :$label bool true" "$ldp" 2>/dev/null \
			|| $PB -c "Set :$label true" "$ldp" 2>/dev/null
		info "disabled $label"
	done
	success "Enrollment daemons disabled (4 overrides)"

	touch "$setupdone" 2>/dev/null || true
}

suppress_only_mode() {
	local data_mount="$1"
	echo ""
	info "Suppress-only mode: no user will be created."
	suppress_enrollment "$data_mount"
	echo ""
	echo -e "${GRN}============================================${NC}"
	echo -e "${GRN}     Enrollment Suppressed                   ${NC}"
	echo -e "${GRN}============================================${NC}"
	echo ""
	echo -e "${CYAN}Reboot to apply.${NC}"
	echo -e "${YEL}After a macOS update: re-run.${NC}"
	echo -e "${YEL}Never run 'profiles renew' or Erase All Content & Settings.${NC}"
}

full_bypass_mode() {
	local data_mount="$1"

	if [ "$DRY_RUN" = true ]; then
		info "[DRY RUN] Would perform full MDM bypass on $data_mount"
		info "[DRY RUN]   - Create admin user"
		info "[DRY RUN]   - Skip Setup Assistant (.AppleSetupDone)"
		info "[DRY RUN]   - Then run suppress_enrollment"
		return 0
	fi

	local node
	node=$(dscl_node "$data_mount")

	echo ""
	step "Creating temporary admin account"

	prompt_default realName "Full name" "Apple"

	local username
	while true; do
		prompt_username username
		if check_user_exists "$node" "$username"; then
			warn "User '$username' already exists."
			if confirm "Delete and recreate?"; then
				delete_user "$node" "$data_mount" "$username"
				break
			else
				echo -e "${YEL}Choose a different username.${NC}"
			fi
		else
			break
		fi
	done

	local passw
	prompt_password passw

	local uid
	uid=$(find_available_uid "$node")
	info "Using UID $uid"

	create_admin_user "$node" "$data_mount" "$username" "$realName" "$passw" "$uid"

	touch "$data_mount/private/var/db/.AppleSetupDone"
	success "Setup Assistant will be skipped"

	add_to_filevault "$username"

	suppress_enrollment "$data_mount"

	echo ""
	echo -e "${GRN}============================================${NC}"
	echo -e "${GRN}      MDM Bypass Complete                     ${NC}"
	echo -e "${GRN}============================================${NC}"
	echo ""
	echo -e "${CYAN}Login:${NC} ${YEL}$username${NC} / ${YEL}$passw${NC}"
	echo -e "${YEL}After macOS update: re-run. Never 'profiles renew'.${NC}"
}
