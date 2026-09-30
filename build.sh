#!/bin/bash
# Builds LastFile.app — requires Xcode Command Line Tools (xcode-select --install)
set -e
cd "$(dirname "$0")"
APP="LastFile.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# Universal binary: Apple Silicon + Intel
swiftc -O -target arm64-apple-macos13.0  -o .build-arm64  main.swift
swiftc -O -target x86_64-apple-macos13.0 -o .build-x86_64 main.swift
lipo -create -output "$APP/Contents/MacOS/LastFile" .build-arm64 .build-x86_64
rm -f .build-arm64 .build-x86_64

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>LastFile</string>
  <key>CFBundleIdentifier</key><string>com.example.lastfile</string>
  <key>CFBundleExecutable</key><string>LastFile</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION:-1.0}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP — run: open $APP"
