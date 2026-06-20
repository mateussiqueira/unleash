#!/bin/bash
set -euo pipefail
VERSION="1.2.0"
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
MAG='\033[1;35m'
NC='\033[0m'

LOG_FILE=""
VERBOSE=false

log() {
  local level="$1"
  local msg="$2"
  local color=""
  local label=""

  case "$level" in
    ERROR)   color="$RED";   label="ERR"  ;;
    WARN)    color="$YEL";   label="WRN"  ;;
    OK)      color="$GRN";   label=" OK"  ;;
    INFO)    color="$BLU";   label="INF"  ;;
    STEP)    color="$CYAN";  label="STP"  ;;
    DEBUG)   color="$MAG";   label="DBG"  ;;
    *)       color="$NC";    label="LOG"  ;;
  esac

  if [ "$level" = "DEBUG" ] && [ "$VERBOSE" = false ]; then
    return
  fi

  local ts
  ts=$(date '+%H:%M:%S')
  echo -e "${color}[${label}]${NC} ${msg}"

  if [ -n "$LOG_FILE" ]; then
    echo "[${ts}] [${label}] ${msg}" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

error_exit() {
  log "ERROR" "$1" >&2
  exit 1
}

warn() {
  log "WARN" "$1"
}

success() {
  log "OK" "$1"
}

info() {
  log "INFO" "$1"
}

step() {
  log "STEP" "$1"
}

debug() {
  log "DEBUG" "$1"
}

header() {
  local title="$1"
  local len="${#title}"
  local line
  line=$(printf '%*s' "$((len + 4))" | tr ' ' '═')
  echo ""
  echo -e "${CYAN}╔${line}╗${NC}"
  echo -e "${CYAN}║  ${title}  ║${NC}"
  echo -e "${CYAN}╚${line}╝${NC}"
  echo ""
}

begin() {
  local label="$1"
  echo -ne "${CYAN}  ${label} ... ${NC}"
}

end_ok() {
  echo -e "${GRN}✓${NC}"
}

end_fail() {
  echo -e "${RED}✗${NC}"
}

prompt_default() {
  local var_name="$1"
  local prompt_text="$2"
  local default="$3"
  local value
  read -p "${CYAN}${prompt_text}${NC} (default '${default}'): " value
  value="${value:=$default}"
  eval "$var_name=\"$value\""
}

confirm() {
  local prompt="$1"
  local response
  read -p "${prompt} (y/N): " response
  [[ "$response" =~ ^[Yy]$ ]]
}


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


validate_username() {
	local u="$1"
	[ -z "$u" ] && { echo "Username cannot be empty" >&2; return 1; }
	[ ${#u} -gt 31 ] && { echo "Username too long (max 31 chars)" >&2; return 1; }
	[[ "$u" =~ ^[a-zA-Z0-9_-]+$ ]] \
		|| { echo "Use only letters, numbers, underscore, hyphen" >&2; return 1; }
	[[ "$u" =~ ^[a-zA-Z_] ]] \
		|| { echo "Must start with a letter or underscore" >&2; return 1; }
	return 0
}

validate_password() {
	[ -z "$1" ] && { echo "Password cannot be empty" >&2; return 1; }
	[ ${#1} -lt 4 ] && { echo "Minimum 4 characters" >&2; return 1; }
	return 0
}

prompt_username() {
	local var_name="$1"
	local value
	while true; do
		read -p "Username (default 'Apple'): " value
		value="${value:=Apple}"
		if msg=$(validate_username "$value"); then
			eval "$var_name=\"$value\""
			return 0
		else
			warn "$msg"
		fi
	done
}

prompt_password() {
	local var_name="$1"
	local value
	while true; do
		read -p "Password (default '1234'): " value
		value="${value:=1234}"
		if msg=$(validate_password "$value"); then
			eval "$var_name=\"$value\""
			return 0
		else
			warn "$msg"
		fi
	done
}


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



PB=/usr/libexec/PlistBuddy

suppress_enrollment() {
	local data_mount="$1"
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


BACKUP_DIR="$(dirname "$(dirname "$0")")/.unleash-backup"

backup_state() {
	local data_mount="$1"
	mkdir -p "$BACKUP_DIR"
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

MDM_BLOCKLIST="mdmenrollment.apple.com deviceenrollment.apple.com iprofiles.apple.com"

install_selective_block() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"

  step "Installing selective pf rules (block MDM only, allow Apple services)..."

  local anchor_dir="${root}/etc/pf.anchors"
  local anchor_file="${anchor_dir}/com.unleash.selective"
  mkdir -p "$anchor_dir"

  > "$anchor_file"

  for d in $MDM_BLOCKLIST; do
    for ip in $(host -t a "$d" 2>/dev/null | awk '/has address/{print $NF}'); do
      echo "block drop out proto {tcp,udp} to {$ip}" >> "$anchor_file"
    done
    for ip in $(host -t aaaa "$d" 2>/dev/null | awk '/has IPv6 addr/{print $NF}'); do
      echo "block drop out proto {tcp,udp} to {$ip}" >> "$anchor_file"
    done
  done

  chmod 644 "$anchor_file"
  success "Selective anchor written: $anchor_file"

  local pf_conf="${root}/etc/pf.conf"
  local anchor_line="anchor \"com.unleash.selective\""
  local load_line="load anchor \"com.unleash.selective\" from \"${anchor_file}\""

  if [ -f "$pf_conf" ]; then
    if grep -q "com.unleash.selective" "$pf_conf" 2>/dev/null; then
      info "pf.conf already has selective anchor"
    else
      echo "" >> "$pf_conf"
      echo "# Added by unleash — selective MDM block (iCloud-safe)" >> "$pf_conf"
      echo "$anchor_line" >> "$pf_conf"
      echo "$load_line" >> "$pf_conf"
      success "pf.conf updated with selective rules"
    fi
  else
    cat > "$pf_conf" <<- EOF
scrub-anchor "com.apple/*"
nat-anchor "com.apple/*"
rdr-anchor "com.apple/*"
dummynet-anchor "com.apple/*"
fwd-anchor "com.apple/*"
anchor "com.apple/*"
load anchor "com.apple" from "/etc/pf.anchors/com.apple"
# Added by unleash — selective MDM block (iCloud-safe)
${anchor_line}
${load_line}
EOF
    success "pf.conf created"
  fi

  if command -v pfctl &>/dev/null; then
    pfctl -e -f "$pf_conf" 2>/dev/null && success "pf rules loaded (iCloud should work)" \
      || warn "pfctl failed"
  fi
}

restore_hosts_based_block() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"
  local hosts="${root}/private/etc/hosts"

  if [ -f "$hosts" ] && grep -q "Added by unleash" "$hosts" 2>/dev/null; then
    info "unleash hosts entries intact"
  fi
}

run_preformat_check() {
  header "Pre-Format MDM Assessment"

  local clean=true

  step "Checking DEP activation record..."
  if [ -f "/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" ]; then
    local org
    org=$(plutil -convert xml1 -o - "/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" 2>/dev/null \
      | grep -iA1 OrganizationName | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
    echo -e "  ${RED}ACTIVE DEP RECORD FOUND${NC}"
    [ -n "$org" ] && echo -e "  ${YEL}Device assigned to: $org${NC}"
    clean=false
  else
    echo -e "  ${GRN}DEP record clean${NC}"
  fi

  step "Checking MDM enrollment URL for this device..."
  if command -v curl &>/dev/null; then
    local enroll_check
    enroll_check=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
      "https://deviceenrollment.apple.com/" 2>/dev/null || echo "000")
    if [ "$enroll_check" = "000" ] || [ "$enroll_check" = "200" ]; then
      echo -e "  ${YEL}deviceenrollment.apple.com reachable${NC}"
    else
      echo -e "  ${GRN}deviceenrollment.apple.com blocked (code $enroll_check)${NC}"
    fi
  else
    echo -e "  ${YEL}curl not available, skipping URL check${NC}"
  fi

  step "Checking MDM enrollment state..."
  if command -v profiles &>/dev/null; then
    local enroll_state
    enroll_state=$(sudo profiles status -type enrollment 2>/dev/null || true)
    if echo "$enroll_state" | grep -qi "enrolled"; then
      echo -e "  ${RED}Device is enrolled in MDM${NC}"
      clean=false
    else
      echo -e "  ${GRN}Not enrolled in MDM${NC}"
    fi
  fi

  step "Checking installed profiles..."
  if command -v profiles &>/dev/null; then
    local profile_count
    profile_count=$(sudo profiles -C -output=xml 2>/dev/null | grep -c "ProfileDisplayName" || echo 0)
    if [ "$profile_count" -gt 0 ]; then
      echo -e "  ${YEL}$profile_count profile(s) installed${NC}"
      clean=false
    else
      echo -e "  ${GRN}No profiles installed${NC}"
    fi
  fi

  step "Checking pf firewall status..."
  if command -v pfctl &>/dev/null; then
    if pfctl -a "com.unleash/mdm" -s rules 2>/dev/null | grep -q "block"; then
      echo -e "  ${GRN}Unleash pf firewall active${NC}"
    else
      echo -e "  ${YEL}No Unleash pf firewall rules${NC}"
    fi
  else
    echo -e "  ${YEL}pfctl not available${NC}"
  fi

  step "Checking persistence LaunchDaemon..."
  if [ -f "/Library/LaunchDaemons/com.unleash.heal.plist" ]; then
    echo -e "  ${GRN}Unleash LaunchDaemon installed (auto-heal on boot)${NC}"
  else
    echo -e "  ${YEL}No Unleash LaunchDaemon${NC}"
  fi

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  if [ "$clean" = true ]; then
    echo -e "${CYAN}║${NC}  ${GRN}SAFE TO FORMAT${NC} — No MDM enrollment detected                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  This Mac should not lock after a wipe.                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  If you want defense-in-depth anyway, run:                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YEL}sudo ./unleash persist && sudo ./unleash firewall${NC}              ${CYAN}║${NC}"
  else
    echo -e "${CYAN}║${NC}  ${RED}MDM DETECTED${NC} — This Mac WILL lock after format                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Run from Recovery after wipe: ${YEL}./unleash bypass${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  To survive macOS updates (not full wipes):                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YEL}sudo ./unleash persist && sudo ./unleash firewall${NC}              ${CYAN}║${NC}"
  fi
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

check_upgrade_safety() {
  header "macOS Upgrade Safety Check"

  step "Checking if suppression will survive upgrade..."
  local issues=0

  if [ -f "/Library/LaunchDaemons/com.unleash.heal.plist" ]; then
    echo -e "  ${GRN}Persistence installed — heal runs after reboot${NC}"
  else
    echo -e "  ${RED}No persistence — upgrade may restore MDM${NC}"
    echo -e "  ${YEL}Fix: sudo ./unleash persist${NC}"
    issues=$((issues + 1))
  fi

  if command -v pfctl &>/dev/null && pfctl -a "com.unleash/mdm" -s rules 2>/dev/null | grep -q "block"; then
    echo -e "  ${GRN}pf firewall active — survives upgrade${NC}"
  else
    echo -e "  ${YEL}No pf firewall — upgrade may restore MDM connectivity${NC}"
    echo -e "  ${YEL}Fix: sudo ./unleash whitelist${NC}"
    issues=$((issues + 1))
  fi

  if grep -q "iprofiles.apple.com" /private/etc/hosts 2>/dev/null; then
    echo -e "  ${GRN}Hosts block active${NC}"
  else
    echo -e "  ${YEL}Hosts block not found${NC}"
    issues=$((issues + 1))
  fi

  echo ""
  if [ "$issues" -eq 0 ]; then
    echo -e "${GRN}Upgrade should be safe — MDM suppression will survive.${NC}"
  else
    echo -e "${YEL}$issues issue(s) found. Run the fixes above before upgrading.${NC}"
  fi
}

install_monitor_launchdaemon() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"

  local unleash_src
  if [ -n "$SCRIPT_DIR" ]; then
    unleash_src="$SCRIPT_DIR/unleash"
  else
    unleash_src="$(cd "$(dirname "$0")" && pwd)/unleash"
  fi

  step "Installing monitor LaunchDaemon..."

  local plist_dir="${root}/Library/LaunchDaemons"
  local plist_path="${plist_dir}/com.unleash.monitor.plist"
  mkdir -p "$plist_dir"

  cat > "$plist_path" <<- PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.unleash.monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>${unleash_src} monitor</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>Nice</key>
    <integer>1</integer>
    <key>StandardOutPath</key>
    <string>/var/log/unleash-monitor.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/unleash-monitor.err</string>
</dict>
</plist>
PLIST

  chmod 644 "$plist_path"
  success "Monitor LaunchDaemon: $plist_path"

  if command -v launchctl &>/dev/null; then
    launchctl load "$plist_path" 2>/dev/null \
      && success "Monitor loaded (starts at boot)" \
      || info "Will load on next boot"
  fi
}

uninstall_monitor_launchdaemon() {
  local data_mount="$1"
  local root=""
  [ -n "$data_mount" ] && root="$data_mount"
  local plist_path="${root}/Library/LaunchDaemons/com.unleash.monitor.plist"

  if [ -f "$plist_path" ]; then
    step "Removing monitor LaunchDaemon..."
    if command -v launchctl &>/dev/null; then
      launchctl unload "$plist_path" 2>/dev/null || true
    fi
    rm -f "$plist_path"
    success "Monitor LaunchDaemon removed"
  else
    info "No monitor LaunchDaemon installed"
  fi
}

monitor_mdm() {
  header "MDM Monitor (continuous)"

  if ! is_root; then
    error_exit "Monitor requires sudo: sudo ./unleash monitor"
  fi

  local logfile="/var/log/unleash-monitor.log"
  local pidfile="/tmp/unleash-monitor.pid"

  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo -e "${YEL}Monitor already running (PID $(cat "$pidfile"))${NC}"
    echo -e "${YEL}Run 'sudo ./unleash monitor-stop' to stop it${NC}"
    return 0
  fi

  echo "$$" > "$pidfile"

  local interval=300
  local consecutive_failures=0
  local last_state=""
  local last_notification=0

  echo "$(date) Monitor started (interval ${interval}s)" >> "$logfile"

  local cfg="/private/var/db/ConfigurationProfiles/Settings"
  local hosts="/private/etc/hosts"

  trap 'echo "$(date) Monitor stopped" >> "$logfile"; rm -f "$pidfile"; exit 0' INT TERM

  while true; do
    local state="clean"
    local reason=""

    if [ -f "$cfg/.cloudConfigRecordFound" ]; then
      state="dirty"
      reason="DEP record found"
    fi

    if [ -f "$hosts" ] && ! grep -q "iprofiles.apple.com" "$hosts" 2>/dev/null; then
      state="dirty"
      reason="Hosts block missing"
    fi

    if command -v profiles &>/dev/null; then
      local enroll_state
      enroll_state=$(profiles status -type enrollment 2>/dev/null || true)
      if echo "$enroll_state" | grep -qi "Enrolled via DEP"; then
        state="dirty"
        reason="DEP enrollment active"
      fi
    fi

    if [ "$state" != "$last_state" ]; then
      echo "$(date) State change: $last_state -> $state ($reason)" >> "$logfile"
      last_state="$state"

      local now
      now=$(date +%s)
      if [ "$state" = "dirty" ] && [ $((now - last_notification)) -gt 3600 ]; then
        last_notification=$now
        if command -v osascript &>/dev/null; then
          osascript -e "display notification \"$reason\" with title \"Unleash MDM Alert\" subtitle \"MDM enrollment detected\"" 2>/dev/null || true
        fi
        heal_suppress ""
      fi
    fi

    if [ "$state" = "dirty" ]; then
      consecutive_failures=$((consecutive_failures + 1))
    else
      consecutive_failures=0
    fi

    if [ "$consecutive_failures" -ge 12 ]; then
      echo "$(date) CRITICAL: 12 consecutive dirty checks" >> "$logfile"
      if command -v osascript &>/dev/null; then
        osascript -e "display dialog \"MDM keeps coming back after 12 attempts. Something is persistently re-enrolling.\" with title \"Unleash\" buttons {\"OK\"} default button \"OK\"" 2>/dev/null || true
      fi
      consecutive_failures=0
    fi

    sleep "$interval" &
    wait $! 2>/dev/null || true
  done
}

stop_monitor() {
  local pidfile="/tmp/unleash-monitor.pid"
  if [ -f "$pidfile" ]; then
    local pid
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      echo -e "${GRN}Monitor stopped${NC}"
    else
      echo -e "${YEL}Monitor not running (stale PID)${NC}"
    fi
    rm -f "$pidfile"
  else
    echo -e "${YEL}Monitor not running${NC}"
  fi
}

monitor_status() {
  local pidfile="/tmp/unleash-monitor.pid"
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo -e "${GRN}Monitor running (PID $(cat "$pidfile"))${NC}"
    tail -5 /var/log/unleash-monitor.log 2>/dev/null || echo "  (no log entries yet)"
  else
    echo -e "${YEL}Monitor not running${NC}"
  fi
}


show_help() {
	cat <<'HELP'
Usage: ./unleash <command> [options]

Bypass / suppress / monitor MDM enrollment on macOS.

  COMMANDS

  Core:
    bypass          Full MDM bypass from Recovery (creates admin user)
    suppress        Silence enrollment, no user created
    heal            Check + re-apply suppression after macOS updates

  Persistence:
    persist         Install LaunchDaemon (auto-heal on every boot)
    unpersist       Remove the persistence LaunchDaemon

  Firewall:
    firewall        Block Apple MDM at kernel level via pf
    firewall-off    Remove pf rules
    whitelist       Block only MDM endpoints, keep iCloud/App Store

  Living System:
    harden          Kill MDM processes + remove profiles + flush DNS
    audit           Deep system scan with risk score

  Monitoring:
    check           Pre-format / pre-upgrade safety report
    monitor         Background daemon (watches MDM every 5 min)
    monitor-install Install monitor as LaunchDaemon (boot persistent)
    monitor-uninstall Remove monitor LaunchDaemon
    monitor-stop    Stop the daemon
    monitor-status  Check if daemon is running

  State:
    backup          Save hosts, profiles, launchd state
    restore         Revert from backup
    dualboot        Target an external macOS install

  Info:
    status          Show MDM enrollment status (Recovery only)
    version         Show version
    help            This message

ALIASES
    st              status
    ls              status
    fw              firewall
    fw-off          firewall-off
    wl              whitelist
    sv              suppress
    by              bypass
    mn              monitor
    mn-install      monitor-install
    mn-uninstall    monitor-uninstall
    mn-stop         monitor-stop
    mn-st           monitor-status

OPTIONS
    --verbose       Show debug messages
    --log-file <f>  Write logs to file (appended)

Run without arguments for interactive menu.
HELP
}

cmd_version() {
	echo "unleash v$VERSION"
	exit 0
}

cmd_bypass() {
	if is_recovery; then
		header "Full MDM Bypass"
		local data_mount
		data_mount=$(resolve_data_volume)
		full_bypass_mode "$data_mount"
	else
		error_exit "Full bypass must run from Recovery mode."
	fi
}

cmd_suppress() {
	header "Suppress Enrollment"
	local data_mount
	data_mount=$(resolve_data_volume)
	suppress_only_mode "$data_mount"
}

cmd_backup() {
	header "Backup"
	local data_mount
	data_mount=$(resolve_data_volume)
	backup_state "$data_mount"
}

cmd_restore() {
	header "Restore"
	restore_state
}

cmd_dualboot() {
	if ! is_root; then
		error_exit "Dual-boot needs sudo: sudo ./unleash dualboot"
	fi

	header "Dual-Boot Mode"

	local volumes
	volumes=$(resolve_target_volumes)
	local sys_path="${volumes%%|*}"
	local data_path="${volumes##*|}"

	info "Target system: $sys_path"
	info "Target data:   $data_path"

	local node
	node=$(dscl_node "$data_path")

	echo ""
	step "Creating admin account on target"

	prompt_default realName "Full name" "Apple"
	local username
	prompt_username username
	local passw
	prompt_password passw
	local uid
	uid=$(find_available_uid "$node")

	create_admin_user "$node" "$data_path" "$username" "$realName" "$passw" "$uid"
	touch "$data_path/private/var/db/.AppleSetupDone"

	begin "Blocking domains"
	local hosts_file="$data_path/private/etc/hosts"
	[ -f "$hosts_file" ] || touch "$hosts_file"
	echo "0.0.0.0 deviceenrollment.apple.com" >>"$hosts_file"
	echo "0.0.0.0 mdmenrollment.apple.com"    >>"$hosts_file"
	echo "0.0.0.0 iprofiles.apple.com"        >>"$hosts_file"
	end_ok

	begin "Resetting config profiles"
	local config_path="$data_path/private/var/db/ConfigurationProfiles/Settings"
	mkdir -p "$config_path"
	rm -f "$config_path/.cloudConfigHasActivationRecord" \
	      "$config_path/.cloudConfigRecordFound"
	touch "$config_path/.cloudConfigProfileInstalled" \
	      "$config_path/.cloudConfigRecordNotFound"
	end_ok

	info "User: $username"
	info "Pass: $passw"
	info "Boot the target and login."
}

cmd_heal() {
	if is_recovery; then
		local data_mount
		data_mount=$(resolve_data_volume)
		heal_suppress "$data_mount"
	else
		if ! is_root; then
			error_exit "Heal needs sudo: sudo ./unleash heal"
		fi
		heal_suppress ""
	fi
}

cmd_persist() {
	local data_mount
	if is_recovery; then
		data_mount=$(resolve_data_volume)
	else
		if ! is_root; then
			error_exit "Persistence needs sudo: sudo ./unleash persist"
		fi
		data_mount=""
	fi
	install_persist_launchdaemon "$data_mount"
}

cmd_unpersist() {
	local data_mount
	if is_recovery; then
		data_mount=$(resolve_data_volume)
	else
		data_mount=""
	fi
	remove_persist_launchdaemon "$data_mount"
}

cmd_firewall() {
	if ! is_root; then
		error_exit "Firewall needs sudo: sudo ./unleash firewall"
	fi
	if is_recovery; then
		local data_mount
		data_mount=$(resolve_data_volume)
		install_pf_mdm_block "$data_mount"
	else
		install_pf_mdm_block ""
	fi
}

cmd_firewall_off() {
	if ! is_root; then
		error_exit "Needs sudo: sudo ./unleash firewall-off"
	fi
	if is_recovery; then
		local data_mount
		data_mount=$(resolve_data_volume)
		remove_pf_mdm_block "$data_mount"
	else
		remove_pf_mdm_block ""
	fi
}

cmd_harden() {
	if ! is_root; then
		error_exit "Hardening needs sudo: sudo ./unleash harden"
	fi
	if is_recovery; then
		info "In Recovery — will skip live-OS checks"
	fi
	harden_live_os
}

cmd_audit() {
	if ! is_root; then
		error_exit "Audit needs sudo: sudo ./unleash audit"
	fi
	deep_status
}

cmd_whitelist() {
	if ! is_root; then
		error_exit "Whitelist needs sudo: sudo ./unleash whitelist"
	fi
	if is_recovery; then
		local data_mount
		data_mount=$(resolve_data_volume)
		install_selective_block "$data_mount"
	else
		install_selective_block ""
	fi
}

cmd_status() {
	if is_recovery; then
		local data_mount
		data_mount=$(resolve_data_volume)
		check_mdm_status "$data_mount"
	else
		error_exit "Status works from Recovery. Try 'check' or 'audit' instead."
	fi
}

cmd_check() {
  if ! is_root; then
    error_exit "Check needs sudo: sudo ./unleash check"
  fi
  run_preformat_check
  echo ""
  check_upgrade_safety
}

cmd_monitor() {
  case "${2:-}" in
    install)   install_monitor_launchdaemon "" ;;
    uninstall) uninstall_monitor_launchdaemon "" ;;
    *)         monitor_mdm ;;
  esac
}
cmd_monitor_stop() { stop_monitor; }
cmd_monitor_status() { monitor_status; }

cmd_interactive_recovery() {
	header "unleash"

	local data_mount
	data_mount=$(resolve_data_volume)
	echo ""

	PS3="Choose: "
	local options=(
		"Full bypass (create admin + suppress MDM)"
		"Suppress enrollment only"
		"Auto-heal"
		"Install pf firewall"
		"Remove pf firewall"
		"Install selective block (iCloud-safe)"
		"Live-OS harden"
		"Deep MDM audit"
		"Backup state"
		"Restore from backup"
		"Check MDM status"
		"Pre-format check"
		"Reboot"
		"Exit"
	)
	select opt in "${options[@]}"; do
		case $opt in
			"Full bypass (create admin + suppress MDM)")
				full_bypass_mode "$data_mount"
				info "Reboot to apply."
				;;
			"Suppress enrollment only")
				suppress_only_mode "$data_mount"
				;;
			"Auto-heal")
				heal_suppress "$data_mount"
				;;
			"Install pf firewall")
				install_pf_mdm_block "$data_mount"
				;;
			"Remove pf firewall")
				remove_pf_mdm_block "$data_mount"
				;;
			"Install selective block (iCloud-safe)")
				install_selective_block "$data_mount"
				;;
			"Live-OS harden")
				harden_live_os
				;;
			"Deep MDM audit")
				deep_status
				;;
			"Backup state")
				backup_state "$data_mount"
				;;
			"Restore from backup")
				restore_state
				;;
			"Check MDM status")
				check_mdm_status "$data_mount"
				;;
			"Pre-format check")
				run_preformat_check
				;;
			"Reboot")
				info "Rebooting..."
				reboot
				;;
			"Exit")
				exit 0
				;;
			*)
				echo -e "${RED}Invalid option $REPLY${NC}"
				;;
		esac
	done
}

cmd_interactive_normal() {
	header "unleash"
	echo -e "${YEL}Not in Recovery. Limited options.${NC}"
	echo "  Try: sudo ./unleash heal | harden | audit | check | monitor"
	echo ""

	PS3="Choose: "
	local options=(
		"Auto-heal"
		"Backup state"
		"Restore from backup"
		"Exit"
	)
	select opt in "${options[@]}"; do
		case $opt in
		"Auto-heal")
			if ! is_root; then
				error_exit "Heal needs sudo. Run: sudo ./unleash"
			fi
			heal_suppress ""
			;;
		"Backup state")
			local data_mount
			data_mount=$(resolve_data_volume)
			backup_state "$data_mount"
			;;
		"Restore from backup")
			restore_state
			;;
		"Exit")
			exit 0
			;;
		*)
			echo -e "${RED}Invalid $REPLY${NC}"
			;;
		esac
	done
}

parse_global_opts() {
	local args=()
	while [ $# -gt 0 ]; do
		case "$1" in
			--verbose) VERBOSE=true; shift ;;
			--log-file) LOG_FILE="$2"; shift 2 ;;
			*) args+=("$1"); shift ;;
		esac
	done
	set -- "${args[@]}"
	echo "$@"
}

main() {
	eval "set -- $(parse_global_opts "$@")"

	case "${1:-}" in
		bypass|by)       cmd_bypass ;;
		suppress|sv)     cmd_suppress ;;
		heal)             cmd_heal ;;
		persist)          cmd_persist ;;
		unpersist)        cmd_unpersist ;;
		firewall|fw)      cmd_firewall ;;
		firewall-off|fw-off) cmd_firewall_off ;;
		harden)           cmd_harden ;;
		audit)            cmd_audit ;;
		whitelist|wl)     cmd_whitelist ;;
		backup)           cmd_backup ;;
		restore)          cmd_restore ;;
		dualboot)         cmd_dualboot ;;
		status|st|ls)     cmd_status ;;
		check)            cmd_check ;;
		monitor|mn)           cmd_monitor "$@" ;;
		monitor-install|mn-install) install_monitor_launchdaemon "" ;;
		monitor-uninstall|mn-uninstall) uninstall_monitor_launchdaemon "" ;;
		monitor-stop|mn-stop) cmd_monitor_stop ;;
		monitor-status|mn-st) cmd_monitor_status ;;
		version|-v|--version) cmd_version ;;
		help|-h|--help)   show_help; exit 0 ;;
		"")
			if is_recovery; then
				cmd_interactive_recovery
			else
				cmd_interactive_normal
			fi
			;;
		*)
			echo -e "${RED}Unknown: $1${NC}" >&2
			show_help >&2
			exit 1
			;;
	esac
}

main "$@"
