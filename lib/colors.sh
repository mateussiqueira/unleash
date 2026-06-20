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
