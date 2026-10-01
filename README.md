# LastFile

Menu bar app for macOS. Press **⌥⌘V** and your newest download or screenshot
is pasted into whatever app you're in. **⇧⌥⌘V** shows the last 5 files to pick from.

## Install

**Homebrew (recommended)**
```
brew install --cask YOUR_USER/tap/lastfile
```

**No Homebrew? One-line installer**
```
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/LastFile/main/install.sh | bash
```

Both avoid the macOS "can't be opened" warning. Then grant **Accessibility** permission when
prompted (System Settings → Privacy & Security → Accessibility).

**Manual download:** the zip on the Releases page works, but macOS will block it until you run
`xattr -dr com.apple.quarantine /Applications/LastFile.app`.

Requires macOS 13+. Apple Silicon and Intel.

## Build it yourself
```
./build.sh && open LastFile.app
```
