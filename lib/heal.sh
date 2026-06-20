# unleash/lib/heal.sh — Self-healing and boot persistence

heal_suppress() {
	local data_mount="$1"
	[ -z "$data_mount" ] && data_mount=""

	step "Checking current MDM suppression state..."
	local cfg="${data_mount}/private/var/db/ConfigurationProfiles/Settings"
	local hosts="${data_mount}/private/etc/hosts"
	local ldp="${data_mount}/private/var/db/com.apple.xpc.launchd/disabled.plist"

	local needs_heal=false

	if [ -f "$cfg/.cloudConfigRecordFound" ]; then
		warn "DEP activation record present"
		needs_heal=true
	else
		info "DEP markers clean"
	fi

	if [ -f "$hosts" ]; then
		if grep -q "iprofiles.apple.com" "$hosts" 2>/dev/null; then
			info "Domain block active"
		else
			warn "Domain block missing"
			needs_heal=true
		fi
	else
		warn "Hosts file missing"
		needs_heal=true
	fi

	if [ -f "$ldp" ]; then
		local missing=0
		for label in com.apple.ManagedClient.enroll com.apple.mdmclient.daemon.runatboot; do
			$PB -c "Print :$label" "$ldp" 2>/dev/null | grep -q "true" || missing=$((missing + 1))
		done
		if [ "$missing" -gt 0 ]; then
			warn "$missing enrollment daemon(s) not disabled"
			needs_heal=true
		else
			info "Enrollment daemons disabled"
		fi
	else
		warn "Launchd override missing"
		needs_heal=true
	fi

	if [ "$needs_heal" = false ]; then
		success "MDM suppression intact — no action needed"
		return 0
	fi

	step "Re-applying MDM suppression..."
	suppress_enrollment "$data_mount"
	success "MDM suppression restored"
}

_persist_mount_root() {
	local dm="$1"
	if [ -z "$dm" ] || [ ! -d "$dm/Library" ]; then
		echo ""
	else
		echo "$dm"
	fi
}

install_persist_launchdaemon() {
	local data_mount="$1"
	local root
	root="$(_persist_mount_root "$data_mount")"

	local unleash_src
	if [ -n "$SCRIPT_DIR" ]; then
		unleash_src="$SCRIPT_DIR/unleash"
	else
		unleash_src="$(cd "$(dirname "$0")" && pwd)/unleash"
	fi

	step "Installing LaunchDaemon for boot-time persistence..."

	local plist_dir="${root}/Library/LaunchDaemons"
	local plist_path="${plist_dir}/com.unleash.heal.plist"

	mkdir -p "$plist_dir"

	cat > "$plist_path" <<- PLIST
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
		<key>Label</key>
		<string>com.unleash.heal</string>
		<key>ProgramArguments</key>
		<array>
			<string>/bin/bash</string>
			<string>-c</string>
			<string>${unleash_src} heal</string>
		</array>
		<key>RunAtLoad</key>
		<true/>
		<key>StartInterval</key>
		<integer>86400</integer>
		<key>Nice</key>
		<integer>1</integer>
		<key>KeepAlive</key>
		<false/>
		<key>StandardOutPath</key>
		<string>/var/log/unleash-heal.log</string>
		<key>StandardErrorPath</key>
		<string>/var/log/unleash-heal.err</string>
	</dict>
	</plist>
	PLIST

	chmod 644 "$plist_path"
	success "LaunchDaemon written to $plist_path"

	step "Loading LaunchDaemon..."
	if command -v launchctl &>/dev/null; then
		launchctl load "$plist_path" 2>/dev/null \
			&& success "LaunchDaemon loaded (will run on next boot)" \
			|| info "LaunchDaemon will load on next boot"
	else
		info "launchctl not available (expected in Recovery) — will load on next boot"
	fi
}

remove_persist_launchdaemon() {
	local data_mount="$1"
	local root
	root="$(_persist_mount_root "$data_mount")"
	local plist_path="${root}/Library/LaunchDaemons/com.unleash.heal.plist"

	if [ -f "$plist_path" ]; then
		step "Removing Unleash LaunchDaemon..."
		if command -v launchctl &>/dev/null; then
			launchctl unload "$plist_path" 2>/dev/null || true
		fi
		rm -f "$plist_path"
		success "LaunchDaemon removed"
	else
		info "No Unleash LaunchDaemon installed"
	fi
}
