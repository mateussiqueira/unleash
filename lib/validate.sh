
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
