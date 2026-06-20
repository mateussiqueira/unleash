#!/bin/bash
OUT="unleash-standalone.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

VERSION="$(grep '^VERSION=' "$SCRIPT_DIR/unleash" | head -1 | cut -d'"' -f2)"
[ -z "$VERSION" ] && VERSION="1.0.0"

cat > "$OUT" << HEADER
#!/bin/bash
set -euo pipefail
VERSION="$VERSION"
HEADER

for lib in colors detect validate dscl suppress backup status heal firewall harden whitelist check monitor history; do
  tail -n +1 "$SCRIPT_DIR/lib/$lib.sh" >> "$OUT"
  echo "" >> "$OUT"
done

sed -e '1,/_lib in /d' -e '/^done$/,$!d' -e '/^done$/d' "$SCRIPT_DIR/unleash" >> "$OUT"

chmod +x "$OUT"
echo "Created: $OUT (v$VERSION, $(wc -c < "$OUT") bytes, $(wc -l < "$OUT") lines)"
