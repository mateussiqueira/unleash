#!/bin/bash
# record-demo.sh
# Generates a terminal demo output for README/site.
# Run: bash record-demo.sh > demo-output.txt

echo "$ ./unleash --version"
./unleash --version
echo ""

echo "$ sudo ./unleash doctor"
echo "[SUDO] Simulated doctor output for demo:"
echo "  ✓ Script location: /Users/user/unleash"
echo "  ✓ Library files: 21/21 modules loaded"
echo "  ✓ Root privileges"
echo "  ⚠ Recovery mode: no (limited to booted commands)"
echo "  ✓ Disk space: 89234 MB free"
echo "  ✓ pfctl available"
echo "  ✓ profiles command"
echo "  ✓ launchctl available"
echo "  ⚠ Third-party firewall: Little Snitch detected"
echo ""

echo "$ sudo ./unleash check"
sudo ./unleash check 2>/dev/null || echo "[DEMO] Would show pre-format assessment"
echo ""

echo "$ sudo ./unleash audit"
echo "[DEMO] Audit scan complete:"
echo "  Profiles: 0"
echo "  DEP record: clean"
echo "  Risk: LOW"
echo ""

echo "$ ./unleash --version"
./unleash --version
