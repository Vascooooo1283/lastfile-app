import Cocoa
import Carbon
import ServiceManagement

// MARK: - Config

let ignoredExtensions: Set<String> = ["crdownload", "download", "part", "partial", "tmp", "opdownload"]

struct Source {
    let key: String
    let title: String
    let url: URL
}

var appInstance: LastFileApp!

// MARK: - App

final class LastFileApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotKeyRefs: [EventHotKeyRef?] = []
    var pickerTarget: NSRunningApplication?

    lazy var sources: [Source] = {
        let fm = FileManager.default
        var list: [Source] = []
        if let d = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            list.append(Source(key: "downloads", title: "Downloads", url: d))
        }
        if let d = fm.urls(for: .desktopDirectory, in: .userDomainMask).first {
            list.append(Source(key: "desktop", title: "Desktop", url: d))
        }
        // Screenshot folder (falls back to Desktop if unset)
        let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        let shots = custom.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        if let shots = shots, !list.contains(where: { $0.url.path == shots.path }) {
            list.append(Source(key: "screenshots", title: "Screenshots folder", url: shots))
        }
        return list
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "src.downloads": true, "src.desktop": false, "src.screenshots": true
        ])
        setupStatusItem()
        registerHotKeys()
        if !AXIsProcessTrusted() { requestAccessibility() }
    }

    // MARK: Status item & menu

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "paperclip.circle", accessibilityDescription: "LastFile")
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        let h1 = NSMenuItem(title: "⌥⌘V  Paste newest file", action: nil, keyEquivalent: "")
        let h2 = NSMenuItem(title: "⇧⌥⌘V  Pick from last 5", action: nil, keyEquivalent: "")
        h1.isEnabled = false; h2.isEnabled = false
        menu.addItem(h1); menu.addItem(h2)
        menu.addItem(.separator())

        let label = NSMenuItem(title: "Watch folders", action: nil, keyEquivalent: "")
        label.isEnabled = false
        menu.addItem(label)
        for s in sources {
            let item = NSMenuItem(title: s.title, action: #selector(toggleSource(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = s.key
            item.state = isEnabled(s.key) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        if !AXIsProcessTrusted() {
            let ax = NSMenuItem(title: "Grant Accessibility permission…", action: #selector(axAction), keyEquivalent: "")
            ax.target = self
            menu.addItem(ax)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit LastFile", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func isEnabled(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: "src.\(key)") }

    @objc func toggleSource(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        UserDefaults.standard.set(!isEnabled(key), forKey: "src.\(key)")
        rebuildMenu()
    }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { NSSound.beep() }
        rebuildMenu()
    }

    @objc func axAction() { requestAccessibility() }

    func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: Finding files

    func recentFiles(limit: Int) -> [URL] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .addedToDirectoryDateKey, .creationDateKey, .fileSizeKey]
        var seen = Set<String>()
        var found: [(URL, Date)] = []

        for s in sources where isEnabled(s.key) {
            guard let items = try? fm.contentsOfDirectory(at: s.url, includingPropertiesForKeys: keys,
                                                          options: [.skipsHiddenFiles]) else { continue }
            for url in items {
                guard seen.insert(url.path).inserted else { continue }
                guard !ignoredExtensions.contains(url.pathExtension.lowercased()) else { continue }
                guard let v = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                if v.isDirectory == true { continue }
                if (v.fileSize ?? 0) == 0 { continue }
                let date = v.addedToDirectoryDate ?? v.creationDate ?? .distantPast
                found.append((url, date))
            }
        }
        return found.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }

    // MARK: Hotkeys

    func registerHotKeys() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            DispatchQueue.main.async { appInstance.hotKeyPressed(hk.id) }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &spec, nil, nil)

        func reg(_ id: UInt32, _ mods: Int) {
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: OSType(0x4C465631), id: id)
            RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(mods), hkID, GetApplicationEventTarget(), 0, &ref)
            hotKeyRefs.append(ref)
        }
        reg(1, cmdKey | optionKey)
        reg(2, cmdKey | optionKey | shiftKey)
    }

    func hotKeyPressed(_ id: UInt32) {
        let target = NSWorkspace.shared.frontmostApplication
        if id == 1 {
            guard let file = recentFiles(limit: 1).first else { NSSound.beep(); return }
            paste(file, into: target, activate: false)
        } else {
            showPicker(target: target)
        }
    }

    // MARK: Picker

    func showPicker(target: NSRunningApplication?) {
        let files = recentFiles(limit: 5)
        guard !files.isEmpty else { NSSound.beep(); return }
        pickerTarget = target

        let menu = NSMenu()
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        for url in files {
            let added = (try? url.resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate) ?? nil
            let age = added.map { "  —  " + rel.localizedString(for: $0, relativeTo: Date()) } ?? ""
            let item = NSMenuItem(title: url.lastPathComponent + age, action: #selector(pickerChose(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            menu.addItem(item)
        }
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc func pickerChose(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        paste(url, into: pickerTarget, activate: true)
    }

    // MARK: Paste

    func paste(_ url: URL, into target: NSRunningApplication?, activate: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([url as NSURL])

        guard AXIsProcessTrusted() else {
            requestAccessibility()   // File is on the clipboard; ⌘V manually this time.
            return
        }
        if activate { target?.activate() }
        // Short delay lets you release the hotkey modifiers and the target app regain focus.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { LastFileApp.sendCmdV() }
    }

    static func sendCmdV() {
        let src = CGEventSource(stateID: .privateState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = LastFileApp()
appInstance = delegate
app.delegate = delegate
app.run()
