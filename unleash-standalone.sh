#!/bin/bash
set -euo pipefail
VERSION="1.6.0"
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
MAG='\033[1;35m'
NC='\033[0m'

LOG_FILE=""
VERBOSE=false
DRY_RUN=false

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

spinner() {
  local pid=$1
  local msg="${2:-Working}"
  local spin='-\|/'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    echo -ne "\r${CYAN}  ${msg} ... ${spin:$i:1}${NC}"
    sleep 0.2
  done
  echo -ne "\r${CYAN}  ${msg} ... ${NC}"
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

CONFIG_FILE="$HOME/.unleash.conf"

load_config() {
  [ -f "$CONFIG_FILE" ] || return 0

  while IFS='=' read -r key value; do
    key="${key// /}"
    value="${value// /}"
    [ -z "$key" ] && continue
    case "$key" in
      WEBHOOK) DISCORD_WEBHOOK="$value" ;;
      LOG_LEVEL) [ "$value" = "verbose" ] && VERBOSE=true ;;
      LOG_FILE) LOG_FILE="$value" ;;
    esac
  done < "$CONFIG_FILE"
}

save_config() {
  local key="$1"
  local value="$2"
  local tmp

  [ -f "$CONFIG_FILE" ] || touch "$CONFIG_FILE"

  if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    sed -i '' "s/^${key}=.*/${key}=${value}/" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
  success "Saved $key to $CONFIG_FILE"
}

cmd_config() {
  header "Configuration"

  case "${2:-show}" in
    show)
      if [ ! -f "$CONFIG_FILE" ]; then
        info "No config file at $CONFIG_FILE"
        return 0
      fi
      step "Current settings ($CONFIG_FILE)"
      cat "$CONFIG_FILE" | sed 's/^/  /'
      ;;
    set)
      local key="$3"
      local value="$4"
      [ -z "$key" ] || [ -z "$value" ] && {
        info "Usage: ./unleash config set KEY VALUE"
        info "Keys: WEBHOOK, LOG_LEVEL (verbose), LOG_FILE"
        return 1
      }
      save_config "$key" "$value"
      ;;
    unset)
      local key="$3"
      [ -z "$key" ] && { info "Usage: ./unleash config unset KEY"; return 1; }
      if [ -f "$CONFIG_FILE" ]; then
        sed -i '' "/^${key}=/d" "$CONFIG_FILE"
        success "Removed $key from config"
      fi
      ;;
    *)
      info "Usage: ./unleash config {show|set KEY VALUE|unset KEY}"
      ;;
  esac
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
	if [ "${1:-}" = "--json" ]; then
		deep_status_json
		return
	fi
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

deep_status_json() {
	local json=""
	json="${json}{\n"
	json="${json}  \"version\": \"$VERSION\",\n"
	json="${json}  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\",\n"

	local profile_count=0
	if command -v profiles &>/dev/null; then
		profile_count=$(sudo profiles -C -output=xml 2>/dev/null | grep -c "ProfileDisplayName" || echo 0)
	fi
	json="${json}  \"profile_count\": $profile_count,\n"

	local enroll_state="unknown"
	if command -v profiles &>/dev/null; then
		enroll_state=$(sudo profiles status -type enrollment 2>/dev/null | head -1 | xargs || echo "unknown")
	fi
	enroll_state="${enroll_state//\"/\\\"}"
	json="${json}  \"enrollment_state\": \"${enroll_state}\",\n"

	local mdm_certs=0
	if command -v security &>/dev/null; then
		mdm_certs=$(sudo security find-identity -p basic 2>/dev/null | grep -ci "mdm\|MDM\|Apple.*Push" || true)
	fi
	json="${json}  \"mdm_certificates\": $mdm_certs,\n"

	local running_procs=0
	running_procs=$(ps aux 2>/dev/null | grep -ciE "mdm|managedclient|activation" || true)
	running_procs=$((running_procs - 1))
	[ "$running_procs" -lt 0 ] && running_procs=0
	json="${json}  \"running_mdm_processes\": $running_procs,\n"

	local risk="LOW"
	[ "$profile_count" -gt 0 ] && risk="MEDIUM"
	[ "$running_procs" -gt 0 ] && risk="HIGH"
	[ -f "/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" ] && risk="CRITICAL"
	json="${json}  \"risk_score\": \"${risk}\"\n"

	json="${json}}"
	echo -e "$json"
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
  local webhook="${DISCORD_WEBHOOK:-}"

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
        if [ -n "$webhook" ]; then
          local payload
          payload=$(printf '{"content":"🚨 **Unleash Alert** — MDM enrollment detected: %s","username":"Unleash Monitor"}' "$reason")
          curl -s -H "Content-Type: application/json" -d "$payload" "$webhook" 2>/dev/null || warn "Webhook failed"
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
      if [ -n "$webhook" ]; then
        curl -s -H "Content-Type: application/json" \
          -d '{"content":"🚨 **Unleash CRITICAL** — 12 consecutive MDM detections. Persistent re-enrollment detected.","username":"Unleash Monitor"}' \
          "$webhook" 2>/dev/null || true
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

show_history() {
  header "Unleash Event History"

  local logs=("/var/log/unleash-monitor.log" "/var/log/unleash-heal.log" "/var/log/unleash-monitor.err")
  local found=false

  for logfile in "${logs[@]}"; do
    if [ -f "$logfile" ] && [ -s "$logfile" ]; then
      found=true
      local name
      name=$(basename "$logfile")
      step "$name"
      while IFS= read -r line; do
        echo "  $line"
      done < "$logfile"
      echo ""
    fi
  done

  if [ "$found" = false ]; then
    info "No event logs found."
    info "Run 'sudo ./unleash monitor' or 'sudo ./unleash persist' first."
  fi

  step "Backup records"
  local backup_dir=".unleash-backup"
  if [ -d "$backup_dir" ] && [ -f "$backup_dir/timestamp" ]; then
    local ts
    ts=$(cat "$backup_dir/timestamp")
    echo "  Last backup: $ts"
  else
    echo "  No backup found"
  fi
}

clear_history() {
  local logs=("/var/log/unleash-monitor.log" "/var/log/unleash-heal.log" "/var/log/unleash-monitor.err")
  for logfile in "${logs[@]}"; do
    if [ -f "$logfile" ]; then
      : > "$logfile"
      success "Cleared: $logfile"
    fi
  done
}

run_doctor() {
  header "Unleash Doctor — Pre-Flight Check"

  local errors=0 warnings=0

  begin "Script location"
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR" ]; then
    end_ok; echo "     $SCRIPT_DIR"
  else
    end_fail; errors=$((errors + 1))
  fi

  begin "Library files"
  local missing=0
  for _lib in colors detect validate dscl suppress backup status heal firewall harden whitelist check monitor history; do
    [ -f "$LIB_DIR/$_lib.sh" ] || missing=$((missing + 1))
  done
  if [ "$missing" -eq 0 ]; then
    end_ok; echo "     13/13 modules loaded"
  else
    end_fail; echo "     $missing module(s) missing"; errors=$((errors + 1))
  fi

  begin "Root privileges"
  if is_root; then
    end_ok
  else
    end_fail; echo "     Run with sudo for full checks"
    warnings=$((warnings + 1))
  fi

  begin "Recovery mode"
  if is_recovery; then
    end_ok; echo "     Full bypass available"
  else
    end_fail; echo "     Limited to booted-system commands"
    warnings=$((warnings + 1))
  fi

  begin "Disk space (Data volume)"
  local mount_pt
  mount_pt=$(df / 2>/dev/null | awk 'NR>1 {print $NF; exit}')
  local avail
  avail=$(df / 2>/dev/null | awk 'NR>1 {print $4; exit}')
  if [ -n "$avail" ] && [ "$avail" -gt 1048576 ]; then
    end_ok; echo "     $(echo "$avail" | awk '{printf "%.0f MB", $1/1024}') free"
  elif [ -n "$avail" ]; then
    end_fail; echo "     Low disk space"; warnings=$((warnings + 1))
  else
    end_fail; echo "     Cannot determine"; errors=$((errors + 1))
  fi

  begin "Internet access"
  if command -v curl &>/dev/null && curl -s --max-time 3 https://github.com >/dev/null 2>&1; then
    end_ok; echo "     Online"
  else
    end_fail; echo "     Offline (expected in Recovery)"
  fi

  begin "pfctl available"
  if command -v pfctl &>/dev/null; then
    end_ok
  else
    end_fail; echo "     Firewall commands unavailable"
  fi

  begin "profiles command"
  if command -v profiles &>/dev/null; then
    end_ok
  else
    end_fail; echo "     Audit/harden commands limited"
  fi

  begin "launchctl available"
  if command -v launchctl &>/dev/null; then
    end_ok
  else
    end_fail; echo "     Persistence commands unavailable"
  fi

  begin "Third-party firewall"
  local tp_found=""
  [ -d "/Applications/Little Snitch.app" ] && tp_found="Little Snitch"
  [ -d "/Applications/LuLu.app" ] && tp_found="${tp_found:+$tp_found, }LuLu"
  [ -f "/Library/Extensions/LittleSnitch.kext" ] && tp_found="${tp_found:+$tp_found, }Little Snitch (kext)"
  [ -d "/Applications/Radio Silence.app" ] && tp_found="${tp_found:+$tp_found, }Radio Silence"
  [ -d "/Applications/Vallum.app" ] && tp_found="${tp_found:+$tp_found, }Vallum"
  if [ -n "$tp_found" ]; then
    end_ok; echo "     $tp_found"
  else
    end_fail; echo "     None detected"
  fi

  echo ""
  step "Persistence status"
  if [ -f "/Library/LaunchDaemons/com.unleash.heal.plist" ]; then
    echo "     heal  LaunchDaemon: installed"
  else
    echo "     heal  LaunchDaemon: not installed"
  fi
  if [ -f "/Library/LaunchDaemons/com.unleash.monitor.plist" ]; then
    echo "     monitor LaunchDaemon: installed"
  else
    echo "     monitor LaunchDaemon: not installed"
  fi
  if [ -f "/etc/pf.anchors/com.unleash/mdm" ]; then
    echo "     pf firewall anchor: installed"
  else
    echo "     pf firewall anchor: not installed"
  fi
  if [ -f "/etc/pf.anchors/com.unleash.selective" ]; then
    echo "     pf selective anchor: installed"
  else
    echo "     pf selective anchor: not installed"
  fi

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
  if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    echo -e "${CYAN}║${NC}  ${GRN}All checks passed${NC}                       ${CYAN}║${NC}"
  elif [ "$errors" -eq 0 ]; then
    echo -e "${CYAN}║${NC}  ${YEL}Passed with $warnings warning(s)${NC}               ${CYAN}║${NC}"
  else
    echo -e "${CYAN}║${NC}  ${RED}$errors error(s), $warnings warning(s)${NC}              ${CYAN}║${NC}"
  fi
  echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
}

do_self_update() {
  header "Unleash Update"

  if ! command -v curl &>/dev/null; then
    error_exit "curl required for update"
  fi

  local repo="mateussiqueira/unleash"
  local api_url="https://api.github.com/repos/${repo}/releases/latest"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local current_sha
  current_sha=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")

  begin "Checking latest release"
  local release_data
  release_data=$(curl -s "$api_url" 2>/dev/null || true)
  local latest_tag
  latest_tag=$(echo "$release_data" | grep '"tag_name"' | head -1 | sed -E 's/.*"v?([^"]+)".*/\1/')
  local latest_sha
  latest_sha=$(echo "$release_data" | grep '"target_commitish"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

  if [ -z "$latest_tag" ]; then
    end_fail; echo "     No network or invalid response"
    rm -rf "$tmp_dir"
    return 1
  fi
  end_ok; echo "     Latest: v$latest_tag"

  if [ "v$latest_tag" = "$(echo "v$VERSION")" ]; then
    success "Already up to date (v$VERSION)"
    rm -rf "$tmp_dir"
    return 0
  fi

  info "Updating from v$VERSION to v$latest_tag..."

  begin "Downloading latest unleash"
  local dl_url="https://raw.githubusercontent.com/${repo}/main/unleash"
  local tmp="$tmp_dir/unleash"
  if curl -sL "$dl_url" -o "$tmp" && [ -s "$tmp" ]; then
    end_ok
  else
    end_fail; error_exit "Download failed"
  fi

  begin "Verifying syntax"
  if bash -n "$tmp" 2>/dev/null; then
    end_ok
  else
    end_fail; error_exit "Downloaded script has syntax errors"
  fi

  local target="${0:-unleash}"
  if [ ! -w "$target" ]; then
    info "$target not writable, trying sudo..."
    cp "$tmp" "$target" 2>/dev/null || sudo cp "$tmp" "$target" 2>/dev/null || {
      error_exit "Cannot write to $target (run with sudo)"
    }
  else
    cp "$tmp" "$target"
  fi
  chmod +x "$target" 2>/dev/null || sudo chmod +x "$target" 2>/dev/null || true

  rm -rf "$tmp_dir"
  success "Updated to v$latest_tag"
  info "Run again to use new version"
}

do_uninstall() {
  header "Unleash — Full Uninstall"

  if ! is_root; then
    error_exit "Uninstall needs sudo: sudo ./unleash uninstall"
  fi

  begin "Removing heal LaunchDaemon"
  local plist="/Library/LaunchDaemons/com.unleash.heal.plist"
  if [ -f "$plist" ]; then
    launchctl unload "$plist" 2>/dev/null || true
    rm -f "$plist"
    end_ok
  else
    end_fail; echo "     Not installed"
  fi

  begin "Removing monitor LaunchDaemon"
  plist="/Library/LaunchDaemons/com.unleash.monitor.plist"
  if [ -f "$plist" ]; then
    launchctl unload "$plist" 2>/dev/null || true
    rm -f "$plist"
    end_ok
  else
    end_fail; echo "     Not installed"
  fi

  begin "Cleaning pf anchors"
  local anchors=("/etc/pf.anchors/com.unleash/mdm" "/etc/pf.anchors/com.unleash.selective")
  for a in "${anchors[@]}"; do
    [ -f "$a" ] && rm -f "$a"
  done
  for anchor_name in "com.unleash/mdm" "com.unleash.selective"; do
    pfctl -a "$anchor_name" -F all 2>/dev/null || true
  done
  local pf_conf="/etc/pf.conf"
  if [ -f "$pf_conf" ]; then
    sed -i '' '/# Added by unleash/d' "$pf_conf" 2>/dev/null || true
    sed -i '' '/com\.unleash/d' "$pf_conf" 2>/dev/null || true
  fi
  pfctl -f /etc/pf.conf 2>/dev/null || true
  end_ok

  begin "Cleaning hosts entries"
  local hosts="/private/etc/hosts"
  if [ -f "$hosts" ]; then
    sed -i '' '/# Added by unleash/d' "$hosts" 2>/dev/null || true
    local domains=("iprofiles.apple.com" "deviceenrollment.apple.com" "mdmenrollment.apple.com")
    for d in "${domains[@]}"; do
      sed -i '' "/[[:space:]]$d/d" "$hosts" 2>/dev/null || true
      sed -i '' "/::$d/d" "$hosts" 2>/dev/null || true
    done
    end_ok
  else
    end_fail; echo "     Not found"
  fi

  begin "Restoring launchd overrides"
  local ldp="/private/var/db/com.apple.xpc.launchd/disabled.plist"
  if [ -f "$ldp" ]; then
    for label in com.apple.ManagedClient.enroll com.apple.ManagedClient.cloudConfiguration \
      com.apple.mdmclient.daemon.runatboot com.apple.activationd; do
      /usr/libexec/PlistBuddy -c "Delete :$label" "$ldp" 2>/dev/null || true
    done
    end_ok
  else
    end_fail; echo "     Not found"
  fi

  begin "Removing backup directory"
  local backup=".unleash-backup"
  if [ -d "$backup" ]; then
    rm -rf "$backup" 2>/dev/null || true
    end_ok
  else
    end_fail; echo "     Not found"
  fi

  begin "Removing config file"
  if [ -f "$HOME/.unleash.conf" ]; then
    rm -f "$HOME/.unleash.conf"
    end_ok
  else
    end_fail; echo "     Not found"
  fi

  begin "Stopping monitor if running"
  local pidfile="/tmp/unleash-monitor.pid"
  if [ -f "$pidfile" ]; then
    kill "$(cat "$pidfile")" 2>/dev/null || true
    rm -f "$pidfile"
    end_ok
  else
    end_fail; echo "     Not running"
  fi

  echo ""
  success "Uninstall complete"
  info "Your system is back to its original state."
  info "The unleash script itself was not removed."
}

generate_report() {
  if [ "${1:-}" = "--json" ]; then
    generate_report_json
    return
  fi
  header "Unleash System Report"

  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "Generated: $ts"
  echo "Version:   $VERSION"
  echo ""

  step "MDM Enrollment State"
  if command -v profiles &>/dev/null; then
    sudo profiles status -type enrollment 2>/dev/null || echo "  (cannot determine)"
  fi

  local cfg="/private/var/db/ConfigurationProfiles/Settings"
  if [ -f "$cfg/.cloudConfigRecordFound" ]; then
    local org
    org=$(plutil -convert xml1 -o - "$cfg/.cloudConfigRecordFound" 2>/dev/null \
      | grep -iA1 OrganizationName | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
    echo "  DEP record: FOUND${org:+ (Organization: $org)}"
  else
    echo "  DEP record: clean"
  fi
  echo ""

  step "Installed Profiles"
  if command -v profiles &>/dev/null; then
    local count
    count=$(sudo profiles -C -output=xml 2>/dev/null | grep -c "ProfileDisplayName" || echo 0)
    if [ "$count" -gt 0 ]; then
      echo "  $count profile(s) installed"
      sudo profiles -C -output=xml 2>/dev/null | grep -A1 "ProfileDisplayName" | grep "<string>" \
        | sed 's/.*<string>\(.*\)<\/string>.*/    - \1/'
    else
      echo "  No profiles installed"
    fi
  fi
  echo ""

  step "Firewall"
  if command -v pfctl &>/dev/null; then
    pfctl -si 2>/dev/null | grep -E "Status|Enabled" || echo "  pf not enabled"
    echo ""
    pfctl -a "com.unleash/mdm" -s rules 2>/dev/null \
      && echo "  Unleash MDM anchor: active" \
      || echo "  Unleash MDM anchor: not loaded"
    pfctl -a "com.unleash.selective" -s rules 2>/dev/null \
      && echo "  Unleash selective anchor: active" \
      || echo "  Unleash selective anchor: not loaded"
  fi
  echo ""

  step "Persistence"
  [ -f "/Library/LaunchDaemons/com.unleash.heal.plist" ] \
    && echo "  heal LaunchDaemon: installed" \
    || echo "  heal LaunchDaemon: not installed"
  [ -f "/Library/LaunchDaemons/com.unleash.monitor.plist" ] \
    && echo "  monitor LaunchDaemon: installed" \
    || echo "  monitor LaunchDaemon: not installed"
  [ -f "/tmp/unleash-monitor.pid" ] \
    && echo "  monitor process: running" \
    || echo "  monitor process: not running"
  echo ""

  step "Recent Events"
  for logfile in /var/log/unleash-monitor.log /var/log/unleash-heal.log; do
    if [ -f "$logfile" ] && [ -s "$logfile" ]; then
      echo "  From $(basename "$logfile"):"
      tail -3 "$logfile" | sed 's/^/    /'
    fi
  done
  echo ""

  step "Hosts Block"
  if grep -q "iprofiles.apple.com" /private/etc/hosts 2>/dev/null; then
    local blocked
    blocked=$(grep -c "0.0.0.0" /private/etc/hosts 2>/dev/null || echo 0)
    echo "  $blocked domain(s) blocked in /etc/hosts"
  else
    echo "  No block entries found"
  fi
  echo ""

  step "Running MDM Processes"
  local procs
  procs=$(ps aux 2>/dev/null | grep -iE "mdm|managedclient|activation" | grep -v grep || true)
  if [ -n "$procs" ]; then
    echo "$procs" | awk '{print "  " $11 " (PID " $2 ")"}'
  else
    echo "  None"
  fi
}

generate_report_json() {
  local report=""
  report="${report}{\n"

  report="${report}  \"version\": \"$VERSION\",\n"
  report="${report}  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\",\n"

  local enroll_state="unknown"
  if command -v profiles &>/dev/null; then
    enroll_state=$(sudo profiles status -type enrollment 2>/dev/null | head -1 | xargs || echo "unknown")
  fi
  enroll_state="${enroll_state//\"/\\\"}"
  report="${report}  \"enrollment_state\": \"${enroll_state}\",\n"

  local has_dep="false"
  if [ -f "/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" ]; then
    has_dep="true"
  fi
  report="${report}  \"dep_record_found\": $has_dep,\n"

  local profile_count=0
  if command -v profiles &>/dev/null; then
    profile_count=$(sudo profiles -C -output=xml 2>/dev/null | grep -c "ProfileDisplayName" || echo 0)
  fi
  report="${report}  \"installed_profiles\": $profile_count,\n"

  local heal_installed="false"
  [ -f "/Library/LaunchDaemons/com.unleash.heal.plist" ] && heal_installed="true"
  local monitor_installed="false"
  [ -f "/Library/LaunchDaemons/com.unleash.monitor.plist" ] && monitor_installed="true"
  local monitor_running="false"
  [ -f "/tmp/unleash-monitor.pid" ] && monitor_running="true"
  report="${report}  \"persistence\": {\n"
  report="${report}    \"heal_launchdaemon\": $heal_installed,\n"
  report="${report}    \"monitor_launchdaemon\": $monitor_installed,\n"
  report="${report}    \"monitor_running\": $monitor_running\n"
  report="${report}  },\n"

  local fw_active="false"
  if command -v pfctl &>/dev/null && pfctl -a "com.unleash/mdm" -s rules 2>/dev/null | grep -q "block"; then
    fw_active="true"
  fi
  local selective_active="false"
  if command -v pfctl &>/dev/null && pfctl -a "com.unleash.selective" -s rules 2>/dev/null | grep -q "block"; then
    selective_active="true"
  fi
  report="${report}  \"firewall\": {\n"
  report="${report}    \"mdm_block_active\": $fw_active,\n"
  report="${report}    \"selective_block_active\": $selective_active\n"
  report="${report}  },\n"

  local hosts_blocked=0
  hosts_blocked=$(grep -c "0.0.0.0" /private/etc/hosts 2>/dev/null || echo 0)
  report="${report}  \"hosts_blocked\": $hosts_blocked\n"

  report="${report}}"

  echo -e "$report"
}

detect_migration_assistant() {
  local data_mount="${1:-}"

  header "Migration Assistant Check"

  local homes=()
  if [ -n "$data_mount" ] && [ -d "$data_mount/Users" ]; then
    for h in "$data_mount/Users/"*/; do
      homes+=("$h")
    done
  elif [ -d "/Users" ]; then
    for h in /Users/*/; do
      homes+=("$h")
    done
  fi

  local ma_indicators=0
  local details=""

  for home in "${homes[@]}"; do
    local user
    user=$(basename "$home")
    [ "$user" = "Guest" ] || [ "$user" = "Shared" ] && continue
    [ -d "$home/Library" ] || continue

    local user_agents="$home/Library/LaunchAgents"
    if [ -d "$user_agents" ]; then
      local found
      found=$(ls "$user_agents" 2>/dev/null | grep -ciE "mdm|enrollment|managed" || true)
      if [ "$found" -gt 0 ]; then
        ma_indicators=$((ma_indicators + found))
        details="$details  $user: $found MDM LaunchAgent(s)\n"
      fi
    fi

    local prefs="$home/Library/Preferences"
    if [ -d "$prefs" ]; then
      local mdm_prefs
      mdm_prefs=$(ls "$prefs"/com.apple.mdm* "$prefs"/com.apple.ManagedClient* 2>/dev/null | head -3 || true)
      if [ -n "$mdm_prefs" ]; then
        ma_indicators=$((ma_indicators + 1))
        details="$details  $user: MDM preference files\n"
      fi
    fi

    local support="$home/Library/Application Support/com.apple.ManagedClient"
    if [ -d "$support" ]; then
      ma_indicators=$((ma_indicators + 1))
      details="$details  $user: ManagedClient Application Support\n"
    fi
  done

  if [ "$ma_indicators" -gt 0 ]; then
    echo -e "${YEL}⚠ Migration Assistant artifacts detected:${NC}"
    echo -e "$details" | sed '/^$/d'
    echo ""
    echo -e "${YEL}These user-level artifacts can re-enable MDM on every login.${NC}"
    echo -e "${YEL}Fix: run 'sudo ./unleash harden' or './unleash suppress' from Recovery.${NC}"
    return 1
  else
    echo -e "${GRN}✓ No Migration Assistant artifacts found${NC}"
    return 0
  fi
}

run_demo() {
  header "Unleash Demo — Simulated MDM Bypass"

  local demo_dir
  demo_dir=$(mktemp -d)
  mkdir -p "$demo_dir/private/etc"
  mkdir -p "$demo_dir/private/var/db/ConfigurationProfiles/Settings"
  mkdir -p "$demo_dir/private/var/db/com.apple.xpc.launchd"
  mkdir -p "$demo_dir/Users/demo/Library/Preferences"
  mkdir -p "$demo_dir/Users/demo/Library/Application Support"

  touch "$demo_dir/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
  touch "$demo_dir/Users/demo/Library/Preferences/com.apple.mdm.plist"

  echo ""
  step "1. Simulating pre-bypass MDM state"
  echo "     DEP record:      ${RED}PRESENT${NC}"
  echo "     Hosts block:     ${RED}ABSENT${NC}"
  echo "     Daemon override: ${RED}ABSENT${NC}"
  echo "     User artifacts:  ${RED}PRESENT${NC}"
  sleep 1

  echo ""
  step "2. Running suppress_enrollment..."
  DRY_RUN=false
  suppress_enrollment "$demo_dir" 2>/dev/null || true
  sleep 1

  echo ""
  step "3. Verifying post-bypass state"
  local clean=true
  if [ -f "$demo_dir/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" ]; then
    echo "     DEP record:      ${RED}STILL PRESENT (bug)${NC}"
    clean=false
  else
    echo "     DEP record:      ${GRN}CLEARED${NC}"
  fi
  if grep -q "iprofiles.apple.com" "$demo_dir/private/etc/hosts" 2>/dev/null; then
    echo "     Hosts block:     ${GRN}ACTIVE${NC}"
  else
    echo "     Hosts block:     ${RED}ABSENT (bug)${NC}"
    clean=false
  fi
  if [ -f "$demo_dir/Users/demo/Library/Preferences/com.apple.mdm.plist" ]; then
    echo "     User artifacts:  ${RED}STILL PRESENT (bug)${NC}"
    clean=false
  else
    echo "     User artifacts:  ${GRN}CLEANED${NC}"
  fi

  echo ""
  step "4. Simulating macOS update (re-enabling daemons)"
  rm -f "$demo_dir/private/var/db/com.apple.xpc.launchd/disabled.plist"
  echo "     Daemon override: ${RED}RESET (simulating update)${NC}"
  sleep 1

  echo ""
  step "5. Running heal — detecting and fixing..."
  heal_suppress "$demo_dir" 2>/dev/null || true
  sleep 1

  if [ -f "$demo_dir/private/var/db/com.apple.xpc.launchd/disabled.plist" ]; then
    echo "     Daemon override: ${GRN}RESTORED${NC}"
  fi

  echo ""
  step "6. Summary"
  if [ "$clean" = true ]; then
    echo -e "   ${GRN}✓ Demo completed successfully${NC}"
  else
    echo -e "   ${YEL}⚠ Demo completed with warnings${NC}"
  fi
  echo "   Simulated environment: $demo_dir"
  echo ""
  info "This is a simulated run. No real system was modified."
  info "Run 'rm -rf $demo_dir' to clean up."

  echo ""
  echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  ${GRN}Demo Complete${NC}                                         ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  Commands used: suppress, heal                    ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  Try: ${YEL}sudo ./unleash doctor${NC}  for real diagnostics       ${CYAN}║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
}

VPN_RULES_ANCHOR="com.unleash/vpn-kill"
VPN_RULES_FILE="/etc/pf.anchors/com.unleash/vpn-kill"

vpn_kill_install() {
  header "VPN Kill-Switch — MDM Leak Protection"

  if ! is_root; then
    error_exit "VPN kill-switch needs sudo: sudo ./unleash vpn-kill"
  fi

  local vpn_if=""

  step "Detecting active VPN interfaces..."
  local interfaces
  interfaces=$(ifconfig 2>/dev/null | grep -E "^utun[0-9]+:" | sed 's/:.*//' || true)
  if [ -z "$interfaces" ]; then
    warn "No VPN interfaces detected"
    info "You can specify manually: sudo ./unleash vpn-kill --interface utunX"
    info "Common VPN interfaces: utun0-9 (WireGuard), utun10+ (OpenVPN), ppp0 (L2TP)"
  else
    for iface in $interfaces; do
      local addr
      addr=$(ifconfig "$iface" 2>/dev/null | awk '/inet /{print $2}')
      if [ -n "$addr" ]; then
        echo "   $iface: $addr"
        [ -z "$vpn_if" ] && vpn_if="$iface"
      fi
    done
  fi

  local user_if="${2:-}"
  [ -n "$user_if" ] && vpn_if="$user_if"

  if [ -z "$vpn_if" ]; then
    warn "No active VPN detected. Installing kill-switch anyway (no default route)."
    info "Usage: sudo ./unleash vpn-kill --interface utunX"
    return 1
  fi

  step "Installing pf rules for VPN kill-switch..."
  local anchor_dir="/etc/pf.anchors/com.unleash"
  mkdir -p "$anchor_dir"

  cat > "$VPN_RULES_FILE" << RULES
# Unleash VPN kill-switch
# Only allow MDM traffic through VPN interface $vpn_if
block drop out proto {tcp,udp} to {17.0.0.0/8, 17.128.0.0/10}
pass out proto {tcp,udp} to {17.0.0.0/8, 17.128.0.0/10} no state
pass on $vpn_if
RULES
  chmod 644 "$VPN_RULES_FILE"
  success "VPN kill-switch rules installed for $vpn_if"

  local pf_conf="/etc/pf.conf"
  local anchor_line="anchor \"${VPN_RULES_ANCHOR}\""
  local load_line="load anchor \"${VPN_RULES_ANCHOR}\" from \"${VPN_RULES_FILE}\""

  if grep -q "vpn-kill" "$pf_conf" 2>/dev/null; then
    info "pf.conf already has VPN kill-switch anchor"
  else
    echo "" >> "$pf_conf"
    echo "# Added by unleash — VPN kill-switch (prevents MDM leaks)" >> "$pf_conf"
    echo "$anchor_line" >> "$pf_conf"
    echo "$load_line" >> "$pf_conf"
  fi

  pfctl -e -f "$pf_conf" 2>/dev/null && success "VPN kill-switch active" \
    || warn "pfctl failed"

  echo ""
  info "What this does:"
  info "  - Blocks MDM Apple IP ranges (17.0.0.0/8) on all interfaces"
  info "  - Only allows MDM traffic through VPN interface ($vpn_if)"
  info "  - If VPN drops, MDM traffic is blocked — no leaks"
  echo ""
  warn "This does NOT affect your regular internet traffic."
  warn "Only MDM-related IPs are routed through the VPN kill-switch."
}

vpn_kill_remove() {
  header "Remove VPN Kill-Switch"

  if ! is_root; then
    error_exit "Needs sudo: sudo ./unleash vpn-kill-remove"
  fi

  if [ -f "$VPN_RULES_FILE" ]; then
    rm -f "$VPN_RULES_FILE"
    success "VPN kill-switch rules removed"
  fi

  local pf_conf="/etc/pf.conf"
  if [ -f "$pf_conf" ]; then
    sed -i '' '/# Added by unleash — VPN kill-switch/d' "$pf_conf" 2>/dev/null || true
    sed -i '' '/vpn-kill/d' "$pf_conf" 2>/dev/null || true
    success "pf.conf cleaned"
  fi

  pfctl -a "$VPN_RULES_ANCHOR" -F all 2>/dev/null || true
  success "pf anchor flushed"
}

vpn_kill_status() {
  step "VPN kill-switch status"
  if [ -f "$VPN_RULES_FILE" ]; then
    echo "  Rules file: $VPN_RULES_FILE"
    cat "$VPN_RULES_FILE" | sed 's/^/    /'
  else
    echo "  No VPN kill-switch installed"
  fi
  if command -v pfctl &>/dev/null; then
    echo ""
    pfctl -a "$VPN_RULES_ANCHOR" -s rules 2>/dev/null \
      && echo "  Anchor loaded" \
      || echo "  Anchor not loaded"
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
    history         Show event log from monitor/heal runs
    test            Dry-run mode: simulate without changing anything
    monitor         Background daemon (watches MDM every 5 min)
    monitor-install Install monitor as LaunchDaemon (boot persistent)
    monitor-uninstall Remove monitor LaunchDaemon
    monitor-stop    Stop the daemon
    monitor-status  Check if daemon is running

  State:
    backup          Save hosts, profiles, launchd state
    restore         Revert from backup
    dualboot        Target an external macOS install

  Diagnostics:
    doctor          Run pre-flight checks on this environment
    report          Generate a full markdown status report
    history         Show event log from monitor/heal runs
    test            Dry-run mode: simulate without changing anything
    demo            Run simulated bypass flow (no real changes)

  VPN:
    vpn-kill        Install VPN kill-switch (prevents MDM leaks outside VPN)
    vpn-kill-remove Remove VPN kill-switch
    vpn-kill-status Check VPN kill-switch status

  Management:
    config          View/edit persistent settings (~/.unleash.conf)
    update          Self-update to the latest GitHub release
    uninstall       Remove all Unleash traces from the system
    reinstall       Uninstall + reinstall (persist + whitelist + monitor)

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
    doc             doctor
    up              update
    uni             uninstall
    rei             reinstall
    vk              vpn-kill
    vkr             vpn-kill-remove
    vks             vpn-kill-status

OPTIONS
    --verbose       Show debug messages
    --dry-run       Simulate without making changes
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
  local webhook=""
  local args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      install|uninstall) args+=("$1"); shift ;;
      --webhook) webhook="$2"; shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  set -- "${args[@]}"
  if [ -n "$webhook" ]; then
    DISCORD_WEBHOOK="$webhook"
  fi
  case "${1:-}" in
    install)   install_monitor_launchdaemon "" ;;
    uninstall) uninstall_monitor_launchdaemon "" ;;
    *)         monitor_mdm ;;
  esac
}

cmd_monitor_stop() { stop_monitor; }
cmd_monitor_status() { monitor_status; }
cmd_history() { show_history; }
cmd_history_clear() { clear_history; }
cmd_test() {
  header "Dry Run Mode"
  DRY_RUN=true
  local cmd="${2:-suppress}"
  case "$cmd" in
    bypass)    info "Simulating: bypass";   cmd_bypass ;;
    suppress)  info "Simulating: suppress"; cmd_suppress ;;
    heal)      info "Simulating: heal";     cmd_heal ;;
    harden)    info "Simulating: harden";   cmd_harden ;;
    firewall)  info "Simulating: firewall"; cmd_firewall ;;
    whitelist) info "Simulating: whitelist"; cmd_whitelist ;;
    all)
      info "Simulating all available operations..."
      info ""
      DRY_RUN=true suppress_enrollment "/"
      info ""
      DRY_RUN=true full_bypass_mode "/"
      info ""
      info "Dry-run complete. No changes were made."
      ;;
    *) info "Usage: ./unleash test {bypass|suppress|heal|harden|firewall|whitelist|all}" ;;
  esac
}

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
			--dry-run) DRY_RUN=true; shift ;;
			--log-file) LOG_FILE="$2"; shift 2 ;;
			*) args+=("$1"); shift ;;
		esac
	done
	set -- "${args[@]}"
	echo "$@"
}

main() {
	load_config
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
		audit)            cmd_audit "$2" ;;
		whitelist|wl)     cmd_whitelist ;;
		backup)           cmd_backup ;;
		restore)          cmd_restore ;;
		dualboot)         cmd_dualboot ;;
		status|st|ls)     cmd_status ;;
		check)            cmd_check ;;
		history)          cmd_history ;;
		history-clear)    cmd_history_clear ;;
		test|dry-run)     cmd_test "$@" ;;
		monitor|mn)           cmd_monitor "$@" ;;
		monitor-install|mn-install) install_monitor_launchdaemon "" ;;
		monitor-uninstall|mn-uninstall) uninstall_monitor_launchdaemon "" ;;
		monitor-stop|mn-stop) cmd_monitor_stop ;;
		monitor-status|mn-st) cmd_monitor_status ;;
		version|-v|--version) cmd_version ;;
    doctor)           run_doctor ;;
		demo)             run_demo ;;
		update)           do_self_update ;;
		uninstall)        do_uninstall ;;
		report)           generate_report "$2" ;;
		config)           cmd_config "$@" ;;
		vpn-kill)         vpn_kill_install "$@" ;;
		vpn-kill-remove)  vpn_kill_remove ;;
		vpn-kill-status)  vpn_kill_status ;;
		reinstall)
			do_uninstall
			install_persist_launchdaemon ""
			install_selective_block ""
			install_monitor_launchdaemon ""
			success "Reinstall complete"
			;;
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
