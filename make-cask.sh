#!/bin/bash
# Prints the Homebrew cask for a release.
# Usage: scripts/make-cask.sh <version> <sha256> <github-owner> <repo>
set -e
VERSION="$1"; SHA="$2"; OWNER="$3"; REPO="${4:-LastFile}"

cat <<CASK
cask "lastfile" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/$OWNER/$REPO/releases/download/v#{version}/LastFile.zip"
  name "LastFile"
  desc "Paste your newest download or screenshot with one hotkey"
  homepage "https://github.com/$OWNER/$REPO"

  depends_on macos: ">= :ventura"

  app "LastFile.app"

  # LastFile isn't notarized, so Gatekeeper would block the quarantined download.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/LastFile.app"]
  end

  zap trash: "~/Library/Preferences/com.example.lastfile.plist"

  caveats <<~EOS
    LastFile isn't Apple-notarized; this cask removed the quarantine flag after install.
    On first launch, grant Accessibility permission:
      System Settings > Privacy & Security > Accessibility
    Hotkeys: Option+Cmd+V (newest file), Shift+Option+Cmd+V (pick from last 5)
  EOS
end
CASK
