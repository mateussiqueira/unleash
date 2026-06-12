# unleash/lib/dscl.sh — Directory Services operations

dscl_node() {
	local data_mount="$1"
	echo "$data_mount/private/var/db/dslocal/nodes/Default"
}

check_user_exists() {
	local node="$1"
	local username="$2"
	dscl -f "$node" localhost -read "/Local/Default/Users/$username" >/dev/null 2>&1
}

find_available_uid() {
	local node="$1"
	local uid=501
	while [ $uid -lt 600 ]; do
		dscl -f "$node" localhost -search /Local/Default/Users UniqueID $uid 2>/dev/null \
			| grep -q "UniqueID" || { echo $uid; return 0; }
		uid=$((uid + 1))
	done
	echo 501
}

delete_user() {
	local node="$1"
	local data_mount="$2"
	local username="$3"
	dscl -f "$node" localhost -delete "/Local/Default/Users/$username" 2>/dev/null || true
	rm -rf "$data_mount/Users/$username" 2>/dev/null || true
}

create_admin_user() {
	local node="$1"
	local data_mount="$2"
	local username="$3"
	local realname="$4"
	local password="$5"
	local uid="$6"

	info "Creating admin account: $username"

	dscl -f "$node" localhost -create "/Local/Default/Users/$username" 2>/dev/null \
		|| error_exit "Failed to create user"
	dscl -f "$node" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh" 2>/dev/null
	dscl -f "$node" localhost -create "/Local/Default/Users/$username" RealName "$realname" 2>/dev/null
	dscl -f "$node" localhost -create "/Local/Default/Users/$username" UniqueID "$uid" 2>/dev/null
	dscl -f "$node" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20" 2>/dev/null
	dscl -f "$node" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username" 2>/dev/null

	dscl -f "$node" localhost -passwd "/Local/Default/Users/$username" "$password" 2>/dev/null \
		|| error_exit "Failed to set password"
	dscl -f "$node" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username" 2>/dev/null \
		|| error_exit "Failed to grant admin"

	mkdir -p "$data_mount/Users/$username"
	success "Admin '$username' created (UID $uid)"
}

add_to_filevault() {
	local username="$1"
	if command -v fdesetup &>/dev/null \
		&& fdesetup supportsauthorizedusers 2>/dev/null | grep -q true; then
		fdesetup add -usertoadd "$username" 2>/dev/null || true
	fi
}
