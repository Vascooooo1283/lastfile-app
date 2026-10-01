#!/bin/bash
# Fallback installer (no Homebrew needed). Edit OWNER/REPO below.
set -e
OWNER="YOUR_USER"; REPO="LastFile"
TMP="$(mktemp -d)"
curl -fsSL "https://github.com/$OWNER/$REPO/releases/latest/download/LastFile.zip" -o "$TMP/LastFile.zip"
rm -rf /Applications/LastFile.app
ditto -xk "$TMP/LastFile.zip" /Applications
xattr -dr com.apple.quarantine /Applications/LastFile.app 2>/dev/null || true
open /Applications/LastFile.app
echo "LastFile installed. Grant Accessibility permission when prompted."
