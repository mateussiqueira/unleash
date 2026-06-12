# unleash/lib/colors.sh — UI helpers and color system

RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
MAG='\033[1;35m'
NC='\033[0m'

error_exit() {
	echo -e "${RED}ERROR: $1${NC}" >&2
	exit 1
}

warn() {
	echo -e "${YEL}WARNING: $1${NC}" >&2
}

success() {
	echo -e "${GRN}\u2713 $1${NC}"
}

info() {
	echo -e "${BLU}\u2139 $1${NC}"
}

step() {
	echo -e "${CYAN}\u25b8 $1${NC}"
}

header() {
	local title="$1"
	echo ""
	echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
	echo -e "${CYAN}║  ${title}${NC}"
	echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
	echo ""
}

prompt_default() {
	local var_name="$1"
	local prompt_text="$2"
	local default="$3"
	local value

	read -p "$prompt_text (default '$default'): " value
	value="${value:=$default}"
	eval "$var_name=\"$value\""
}

confirm() {
	local prompt="$1"
	local response
	read -p "$prompt (y/N): " response
	[[ "$response" =~ ^[Yy]$ ]]
}
