# probe.sh — read-only fingerprint of macOS version + MDM enrollment mechanism.
# Produces a version-aware compatibility verdict so other commands can adapt to
# what Apple changes between releases. This module never writes to any volume.

PB="${PB:-/usr/libexec/PlistBuddy}"

# Codename per macOS major. Data lives here so the command and its tests share
# one source of truth; extend it as Apple ships new majors.
probe_codename() {
	case "${1:-}" in
		15) echo "Sequoia" ;;
		26) echo "Tahoe" ;;
		*)  echo "unknown" ;;
	esac
}

# Compatibility verdict per macOS major:
#   supported = confirmed on real hardware
#   testing   = validation in progress on this major
#   untested  = no confirmed run yet
probe_compat() {
	case "${1:-}" in
		15) echo "supported" ;;
		26) echo "testing" ;;
		*)  echo "untested" ;;
	esac
}

_systemversion_plist() {
	echo "${1%/}/System/Library/CoreServices/SystemVersion.plist"
}

# probe_macos_version <volume_root> -> "<product>|<build>" on stdout.
# Reads the target volume's plist (the only version source in Recovery, where
# sw_vers reports the Recovery OS, not the installed one). Non-zero if absent.
probe_macos_version() {
	local root="${1:-/}" plist product build
	plist="$(_systemversion_plist "$root")"
	[ -f "$plist" ] || return 1
	product="$($PB -c "Print :ProductVersion" "$plist" 2>/dev/null)" || return 1
	[ -n "$product" ] || return 1
	build="$($PB -c "Print :ProductBuildVersion" "$plist" 2>/dev/null || true)"
	echo "${product}|${build}"
}

# probe_macos_major <version> -> integer major (26 from 26.1.2). Non-zero if the
# leading field is not numeric.
probe_macos_major() {
	local major="${1:-}"
	major="${major%%.*}"
	case "$major" in
		''|*[!0-9]*) return 1 ;;
	esac
	echo "$major"
}

# probe_enrollment <volume_root> -> dep | profiles | none (read-only).
# Inspects marker files only; changes nothing.
probe_enrollment() {
	local root="${1:-/}"
	root="${root%/}"
	local settings="$root/private/var/db/ConfigurationProfiles/Settings"
	if [ -f "$settings/.cloudConfigRecordFound" ] \
		|| [ -f "$settings/.cloudConfigHasActivationRecord" ]; then
		echo "dep"
		return 0
	fi
	local store="$root/private/var/db/ConfigurationProfiles/Store"
	if [ -d "$store" ] && [ -n "$(ls -A "$store" 2>/dev/null)" ]; then
		echo "profiles"
		return 0
	fi
	echo "none"
}

# probe_dep_detail <volume_root> -> "<org>|<mdm_host>" (either field may be
# empty). Read-only parse of the cached DEP activation record. Mirrors the
# extraction in suppress.sh; kept local to avoid refactoring that module here.
probe_dep_detail() {
	local root="${1:-/}"
	root="${root%/}"
	local rec="$root/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
	[ -f "$rec" ] || { echo "|"; return 1; }
	local org mdm_host
	org=$(plutil -convert xml1 -o - "$rec" 2>/dev/null \
		| grep -iA1 OrganizationName | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/' || true)
	mdm_host=$(plutil -convert xml1 -o - "$rec" 2>/dev/null \
		| grep -ioE 'https?://[a-z0-9._-]+' | sed -E 's#https?://##' \
		| sort -u | grep -viE '(^|\.)apple\.com$' | head -1 || true)
	echo "${org}|${mdm_host}"
}

# probe_suppressed <volume_root> -> 0 when unleash bypass markers are already in
# place. Read-only.
probe_suppressed() {
	local root="${1:-/}"
	root="${root%/}"
	[ -f "$root/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound" ]
}

# cmd_probe [--json] [volume_root] — report version + enrollment + verdict.
# Defaults to "/" (running system); pass a mounted volume in Recovery.
cmd_probe() {
	local json=false root="/" arg
	for arg in "$@"; do
		case "$arg" in
			--json) json=true ;;
			'') : ;;
			*) root="$arg" ;;
		esac
	done

	local ver product="unknown" build="" major="" codename compat enroll
	if ver="$(probe_macos_version "$root")"; then
		product="${ver%%|*}"
		build="${ver#*|}"
		major="$(probe_macos_major "$product" || true)"
	fi
	codename="$(probe_codename "$major")"
	compat="$(probe_compat "$major")"
	enroll="$(probe_enrollment "$root")"

	local org="" mdm_host="" detail suppressed="no"
	if [ "$enroll" = dep ]; then
		detail="$(probe_dep_detail "$root" || true)"
		org="${detail%%|*}"
		mdm_host="${detail#*|}"
	fi
	if probe_suppressed "$root"; then suppressed="yes"; fi

	if [ "$json" = true ]; then
		printf '{"macos_version":"%s","macos_build":"%s","macos_major":"%s","codename":"%s","enrollment":"%s","org":"%s","mdm_host":"%s","suppressed":"%s","compat":"%s"}\n' \
			"$product" "$build" "$major" "$codename" "$enroll" "$org" "$mdm_host" "$suppressed" "$compat"
		return 0
	fi

	header "macOS / MDM Probe"

	step "macOS version"
	info "  Version : $product${build:+ (build $build)}"
	info "  Major   : ${major:-unknown} ($codename)"

	step "Enrollment mechanism"
	case "$enroll" in
		dep)      warn "  DEP activation record present (device is org-assigned)"
		          [ -n "$org" ] && info "  Assigned to : $org"
		          [ -n "$mdm_host" ] && info "  Org MDM host: $mdm_host" ;;
		profiles) warn "  Configuration profiles present" ;;
		*)        success "  No DEP record or profiles detected" ;;
	esac

	step "Suppression state"
	if [ "$suppressed" = yes ]; then
		success "  unleash bypass markers present (already suppressed)"
	else
		info "  No unleash bypass markers (enrollment untouched)"
	fi

	step "Compatibility"
	case "$compat" in
		supported) success "  $codename ($major) — verified on real hardware" ;;
		testing)   warn "  $codename ($major) — validation in progress; run on real hardware and report results" ;;
		*)         warn "  macOS major '${major:-unknown}' — untested; proceed with caution" ;;
	esac
}

# True only when a confirmation prompt makes sense: not a dry run and stdin is a
# terminal. Split out so tests can force the interactive path.
_probe_interactive() {
	[ "${DRY_RUN:-false}" != true ] && [ -t 0 ]
}

# probe_gate <data_mount> — version-aware guard for destructive commands.
# Resolves the System volume (for the macOS version) from the given Data mount,
# reports the compatibility verdict, and asks to confirm before continuing on an
# unverified version. Returns non-zero only when the user declines. Read-only.
probe_gate() {
	local mount="${1:-/}" sysroot sysvol="" ver product="" major="" codename verdict
	sysroot="$mount"
	if command -v detect_system_volume >/dev/null 2>&1; then
		sysvol="$(detect_system_volume "$mount" 2>/dev/null || true)"
		[ -n "$sysvol" ] && [ -d "/Volumes/$sysvol/System" ] && sysroot="/Volumes/$sysvol"
	fi

	if ver="$(probe_macos_version "$sysroot")"; then
		product="${ver%%|*}"
		major="$(probe_macos_major "$product" || true)"
	else
		product="unknown"
	fi
	codename="$(probe_codename "$major")"
	verdict="$(probe_compat "$major")"

	case "$verdict" in
		supported)
			success "macOS $major ($codename) — supported by unleash"
			return 0
			;;
		testing)
			warn "macOS $major ($codename) — compatibility under validation"
			;;
		*)
			warn "macOS $product — untested by unleash; behavior unverified"
			;;
	esac

	if ! _probe_interactive; then
		info "Proceeding without confirmation (dry run or non-interactive)."
		return 0
	fi
	if confirm "Proceed on this macOS version anyway?"; then
		return 0
	fi
	warn "Aborted: macOS version not confirmed."
	return 1
}
