
is_recovery() {
	[ -d "/System/Installation" ] && return 0

	local vol
	vol=$(diskutil info / 2>/dev/null | awk -F': *' '/Volume Name/{print $2}' | xargs)
	case "$vol" in
		"Recovery"*|"macOS Base"*|"macOS Installer"*) return 0 ;;
	esac
	return 1
}

is_root() {
	[[ $EUID -eq 0 ]]
}

resolve_data_volume() {
	step "Locating Data volume by APFS role..."

	local id mount_pt

	id=$(diskutil apfs list 2>/dev/null \
		| awk '/\(Data\)/ && match($0, /disk[0-9]+s[0-9]+/) {print substr($0, RSTART, RLENGTH); exit}')

	if [ -z "$id" ] || ! diskutil info "/dev/$id" >/dev/null 2>&1; then
		info "APFS role detection failed — trying name-based..."
		id=$(diskutil list 2>/dev/null \
			| awk '/[[:space:]]Data[[:space:]]/{for(i=1;i<=NF;i++) if($i ~ /^disk[0-9]+s[0-9]+$/) v=$i} END{print v}')
	fi

	if [ -z "$id" ] || ! diskutil info "/dev/$id" >/dev/null 2>&1; then
		warn "Auto-detection failed. Available disks:"
		diskutil list >&2
		echo ""
		read -p "Enter Data volume identifier (e.g. disk3s1): " id </dev/tty
		id="${id#/dev/}"
	fi

	[ -n "$id" ] || error_exit "No Data volume identifier provided."
	local data_dev="/dev/$id"
	diskutil info "$data_dev" >/dev/null 2>&1 || error_exit "Not a valid disk: $data_dev"
	info "Data volume device: $data_dev"

	_mount_point() {
		diskutil info "$data_dev" 2>/dev/null \
			| awk -F': *' '/Mount Point/{print $2}' | sed 's/[[:space:]]*$//'
	}

	mount_pt=$(_mount_point)

	if [ -z "$mount_pt" ] || [ ! -d "$mount_pt" ]; then
		info "Not mounted — mounting..."
		diskutil mount "$data_dev" 2>/dev/null || true
		mount_pt=$(_mount_point)
	fi

	if [ -z "$mount_pt" ] || [ ! -d "$mount_pt" ]; then
		warn "FileVault-locked — need to unlock."
		echo -e "${YEL}Enter password of a user on this Mac (or FileVault recovery key):${NC}" >&2
		diskutil apfs unlockVolume "$data_dev" 2>/dev/null \
			|| error_exit "Failed to unlock. Re-run with valid credentials."
		mount_pt=$(_mount_point)
	fi

	[ -d "$mount_pt" ] || error_exit "Mount point not found after mount/unlock."
	[ -d "$mount_pt/private/var/db/dslocal/nodes/Default" ] \
		|| error_exit "Not a macOS Data volume (no dslocal node at $mount_pt)."

	success "Data volume: $mount_pt"
	echo "$mount_pt"
}

detect_system_volume() {
	local data_mount="$1"
	local vol

	for vol in /Volumes/*; do
		if [ -d "$vol/System" ] && [ "$vol" != "$data_mount" ]; then
			basename "$vol"
			return 0
		fi
	done

	echo ""
}

resolve_target_volumes() {
	local base_name data_name

	read -p "Enter target system volume name (default 'Macintosh HD'): " base_name
	base_name="${base_name:=Macintosh HD}"
	read -p "Enter target data volume name (default 'Macintosh HD - Data'): " data_name
	data_name="${data_name:=Macintosh HD - Data}"

	local sys_path="/Volumes/$base_name"
	local data_path="/Volumes/$data_name"

	[ -d "$sys_path" ] || error_exit "System volume not found: $sys_path"
	[ -d "$data_path" ] || error_exit "Data volume not found: $data_path"

	echo "$sys_path|$data_path"
}
