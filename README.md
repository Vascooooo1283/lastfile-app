# LastFile

Menu bar app for macOS. Press **⌥⌘V** and your newest download or screenshot
is pasted into whatever app you're in. **⇧⌥⌘V** shows the last 5 files to pick from.

## Install
1. Download `LastFile.zip` from the [Releases](../../releases) page and unzip it.
2. Drag `LastFile.app` to `/Applications`.
3. First launch: **right-click the app → Open → Open** (the app isn't notarized).
   If macOS still refuses, run:
   `xattr -dr com.apple.quarantine /Applications/LastFile.app`
4. Grant **Accessibility** permission when prompted
   (System Settings → Privacy & Security → Accessibility).

Requires macOS 13 or later. Apple Silicon and Intel.

## Build it yourself
```
./build.sh && open LastFile.app
```
