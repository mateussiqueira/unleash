#!/bin/bash
# prepare-ssd.sh
# Prepares an external SSD with unleash + auto-bypass script.
# Run this on a working Mac, before you need the bypass.
#
# Usage:
#   sudo bash prepare-ssd.sh /Volumes/MySSD

SSD="${1:-}"
[ -z "$SSD" ] && { echo "Usage: $0 /Volumes/YourSSD"; exit 1; }
[ -d "$SSD" ] || { echo "SSD not mounted at $SSD"; exit 1; }

SRC="$(cd "$(dirname "$0")/.." && pwd)"

echo "Copying unleash to $SSD..."
cp -R "$SRC" "$SSD/unleash"
cp "$SRC/examples/auto-bypass-usb.sh" "$SSD/auto-bypass-usb.sh"
chmod +x "$SSD/auto-bypass-usb.sh" "$SSD/unleash/unleash"

echo ""
echo "✅ SSD ready at $SSD"
echo ""
echo "To bypass:"
echo "  1. Boot to Recovery (hold Power on AS, Cmd+R on Intel)"
echo "  2. Open Terminal"
echo "  3. Run:"
echo "     chmod +x \"${SSD}/auto-bypass-usb.sh\""
echo "     \"${SSD}/auto-bypass-usb.sh\""
