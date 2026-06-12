#!/bin/bash
# Build a standalone unleash.sh (single file) from modular source.
# Usage: bash build-standalone.sh
# Output: unleash-standalone.sh

OUT="unleash-standalone.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cat > "$OUT" << 'HEADER'
#!/bin/bash
set -euo pipefail

# unleash — Unified MDM bypass tool for macOS (standalone).
# Auto-detects Recovery/dualboot mode. One file, zero dependencies.
#
# Usage:
#   ./unleash [bypass|suppress|backup|restore|dualboot|status|version|help]

VERSION="1.0.0"
HEADER

echo "" >> "$OUT"

for lib in colors detect validate dscl suppress backup status; do
  echo "# === lib/$lib.sh ===" >> "$OUT"
  # Remove shebang lines (first line of each lib)
  tail -n +2 "$SCRIPT_DIR/lib/$lib.sh" >> "$OUT"
  echo "" >> "$OUT"
done

# Append the main script body (skip shebang, skip lib sourcing)
sed -e '1d' -e '/^LIB_DIR=/d' -e '/^for _lib in/,/^done$/d' "$SCRIPT_DIR/unleash" >> "$OUT"

chmod +x "$OUT"
echo "Created: $OUT ($(wc -c < "$OUT") bytes, $(wc -l < "$OUT") lines)"
