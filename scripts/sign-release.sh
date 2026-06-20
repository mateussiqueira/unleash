#!/bin/bash
# scripts/sign-release.sh
# Usage: bash scripts/sign-release.sh <version>
# Signs unleash and unleash-standalone.sh with GPG
set -euo pipefail

VERSION="${1:-}"
[ -z "$VERSION" ] && { echo "Usage: $0 <version>"; exit 1; }

KEY_ID="${GPG_KEY_ID:-}"
[ -z "$KEY_ID" ] && {
  KEY_ID=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep sec | head -1 | awk '{print $2}' | cut -d/ -f2)
}
[ -z "$KEY_ID" ] && { echo "No GPG key found. Generate one: gpg --full-generate-key"; exit 1; }

for file in unleash unleash-standalone.sh; do
  [ -f "$file" ] || continue
  echo "Signing $file..."
  gpg --detach-sign --armor --default-key "$KEY_ID" "$file"
  echo "Created: $file.asc"
done

echo "Done. Verify with: gpg --verify unleash.asc unleash"
