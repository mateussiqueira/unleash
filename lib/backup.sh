
BACKUP_DIR="$(dirname "$(dirname "$0")")/.unleash-backup"

check_disk_space() {
	local data_mount="$1"
	local needed_kb=10240
	local available_kb
	available_kb=$(df -k "$data_mount" 2>/dev/null | tail -1 | awk '{print $4}')
	if [ -n "$available_kb" ] && [ "$available_kb" -lt "$needed_kb" ]; then
		warn "Low disk space: $(echo "$available_kb" | awk '{printf "%.0f MB", $1/1024}') available"
		echo -n "Continue anyway? [y/N] "
		read -r answer
		[ "$answer" != "y" ] && [ "$answer" != "Y" ] && error_exit "Aborted by user"
	fi
}

backup_state() {
	local data_mount="$1"
	mkdir -p "$BACKUP_DIR"
	check_disk_space "$data_mount"
	step "Saving backup to $BACKUP_DIR"

	if [ -f "$data_mount/private/etc/hosts" ]; then
		cp "$data_mount/private/etc/hosts" "$BACKUP_DIR/hosts.backup"
		success "hosts saved"
	fi

	local cfg_src="$data_mount/private/var/db/ConfigurationProfiles/Settings"
	if [ -d "$cfg_src" ]; then
		mkdir -p "$BACKUP_DIR/ConfigurationProfiles"
		cp -r "$cfg_src/"* "$BACKUP_DIR/ConfigurationProfiles/" 2>/dev/null || true
		success "config profiles saved"
	fi

	local ldp_src="$data_mount/private/var/db/com.apple.xpc.launchd/disabled.plist"
	if [ -f "$ldp_src" ]; then
		mkdir -p "$BACKUP_DIR/launchd"
		cp "$ldp_src" "$BACKUP_DIR/launchd/disabled.plist.backup" 2>/dev/null || true
		success "launchd override saved"
	fi

	date +%Y-%m-%d_%H-%M-%S >"$BACKUP_DIR/timestamp"
	echo "$data_mount" >"$BACKUP_DIR/data_volume_path"
	success "Backup complete: $(cat "$BACKUP_DIR/timestamp")"
}

restore_state() {
	[ -f "$BACKUP_DIR/timestamp" ] || error_exit "No backup found at $BACKUP_DIR"

	local data_mount
	if [ -f "$BACKUP_DIR/data_volume_path" ]; then
		data_mount=$(cat "$BACKUP_DIR/data_volume_path")
		if [ ! -d "$data_mount/private/var" ]; then
			warn "Saved path unavailable — re-detecting..."
			data_mount=$(resolve_data_volume)
		fi
	else
		data_mount=$(resolve_data_volume)
	fi

	step "Restoring from backup ($(cat "$BACKUP_DIR/timestamp"))"
	echo -e "${YEL}Target: $data_mount${NC}"

	if [ -f "$BACKUP_DIR/hosts.backup" ]; then
		cp "$BACKUP_DIR/hosts.backup" "$data_mount/private/etc/hosts"
		success "hosts restored"
	fi

	if [ -d "$BACKUP_DIR/ConfigurationProfiles" ]; then
		local cfg="$data_mount/private/var/db/ConfigurationProfiles/Settings"
		mkdir -p "$cfg"
		cp -r "$BACKUP_DIR/ConfigurationProfiles/"* "$cfg/" 2>/dev/null || true
		success "config profiles restored"
	fi

	if [ -f "$BACKUP_DIR/launchd/disabled.plist.backup" ]; then
		local ldp="$data_mount/private/var/db/com.apple.xpc.launchd/disabled.plist"
		mkdir -p "$(dirname "$ldp")"
		cp "$BACKUP_DIR/launchd/disabled.plist.backup" "$ldp"
		success "launchd override restored"
	fi

	sed -i '' '/# Added by unleash/d' "$data_mount/private/etc/hosts" 2>/dev/null || true

	rm -f "$BACKUP_DIR/data_volume_path" "$BACKUP_DIR/timestamp"
	success "Restore complete"
}

has_backup() {
	[ -f "$BACKUP_DIR/timestamp" ]
}
