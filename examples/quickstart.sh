#!/bin/bash
# Usage examples for unleash — copy/paste what you need.

echo "=== unleash quick examples ==="
echo ""
echo "From Recovery (external SSD):"
echo '  "/Volumes/YourSSD/unleash/unleash" bypass'
echo ""
echo "From Recovery (one-liner, needs internet):"
echo "  curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash -o /tmp/unleash && chmod +x /tmp/unleash && /tmp/unleash bypass"
echo ""
echo "From booted system (sudo needed):"
echo "  sudo ./unleash heal        # fix after update"
echo "  sudo ./unleash harden      # cleanup live MDM artifacts"
echo "  sudo ./unleash audit       # deep scan"
echo "  sudo ./unleash check       # pre-format report"
echo "  sudo ./unleash monitor     # watch MDM in background"
echo "  sudo ./unleash persist     # auto-heal on every boot"
echo "  sudo ./unleash firewall    # pf kernel block"
echo "  sudo ./unleash whitelist   # block MDM only, keep iCloud"
