import Cocoa
import SwiftUI
import Combine
import ApplicationServices
import PelmetCore
import PelmetEngine

@MainActor
class MenuBarController: NSObject {
    static let shared = MenuBarController()
    
    private var expandItem: NSStatusItem!
    private var separatorItem: NSStatusItem!
    private var isHidden = false
    private var autoCollapseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?
    private var globalMonitor: Any?
    
    // The private API assertion object
    private var activeAssertion: AssessmentAssertion?
    
    // Asynchronous item enumerator that reads MenuBarAgent via Accessibility
    private let enumerator = ItemEnumerator()
    
    private let prefs = PreferencesManager.shared
    
    override init() {
        super.init()
    }
    
    func setup() {
        // 1. Separator Item (the divider `|`)
        separatorItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        separatorItem.autosaveName = "HideBar.separator"
        separatorItem.behavior = [.removalAllowed]
        if let btn = separatorItem.button {
            btn.title = "|"
            btn.font = NSFont.systemFont(ofSize: 14, weight: .light)
            btn.target = self
            btn.action = #selector(handleSeparatorClick)
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 2. Toggle Control Item (Chevron)
        expandItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        expandItem.autosaveName = "HideBar.expand"
        expandItem.behavior = [.removalAllowed]
        if let btn = expandItem.button {
            updateButtonAppearance(button: btn)
            btn.action = #selector(handleStatusItemClick)
            btn.target = self
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Setup Global Hotkey (Cmd + Control + H) to always allow unhiding
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifierFlags == [.command, .control] && event.keyCode == 4 { // 'h' key
                Task { @MainActor in
                    self?.toggle()
                }
            }
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifierFlags == [.command, .control] && event.keyCode == 4 {
                Task { @MainActor in
                    self?.toggle()
                }
                return nil
            }
            return event
        }
        
        // Setup Shelf Window Callbacks
        ShelfWindowController.shared.setup(
            onToggle: { [weak self] in
                self?.toggle()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
        
        setupObservers()
        checkAccessibilityPermissions()
    }
    
    private func checkAccessibilityPermissions() {
        if !AXIsProcessTrusted() {
            logToFile("⚠️ HideBar requesting Accessibility permission.")
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
    
    private func logToFile(_ message: String) {
        print(message)
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hidebar_log.txt")
        let text = "\(Date()): \(message)\n"
        if let data = text.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
    
    private func setupObservers() {
        prefs.$iconStyle
            .sink { [weak self] _ in
                guard let self = self, let btn = self.expandItem?.button else { return }
                self.updateButtonAppearance(button: btn)
            }
            .store(in: &cancellables)
            
        prefs.$showSeparator
            .sink { [weak self] show in
                guard let self = self, let sep = self.separatorItem else { return }
                sep.isVisible = show
            }
            .store(in: &cancellables)
    }
    
    private func updateButtonAppearance(button: NSStatusBarButton) {
        if let symbolName = isHidden ? prefs.iconStyle.collapsedIcon : prefs.iconStyle.expandedIcon {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "HideBar Toggle")?.withSymbolConfiguration(config)
            button.title = ""
        } else {
            button.title = isHidden ? prefs.customTextCollapsed : prefs.customTextExpanded
            button.image = nil
        }
    }
    
    @objc private func handleSeparatorClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        }
    }
    
    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            toggle()
        }
    }
    
    func toggle() {
        isHidden.toggle()
        
        autoCollapseTimer?.invalidate()
        autoCollapseTimer = nil
        
        if isHidden {
            Task {
                await applyHideBasedOnCoordinates()
            }
            ShelfWindowController.shared.hide()
        } else {
            // Restore all items
            if let assertion = activeAssertion {
                assertion.invalidate()
                activeAssertion = nil
                print("✅ Invalidation complete: all items restored.")
            }
            
            if prefs.showFloatingShelf {
                ShelfWindowController.shared.showUnderStatusItem(button: expandItem.button)
            }
            
            if prefs.autoCollapseDelay > 0 {
                autoCollapseTimer = Timer.scheduledTimer(withTimeInterval: prefs.autoCollapseDelay, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        if let self = self, !self.isHidden {
                            self.toggle()
                        }
                    }
                }
            }
        }
        
        if let btn = expandItem.button {
            updateButtonAppearance(button: btn)
        }
    }
    
    /// Production-grade coordinate calculation:
    /// Scans all menu bar items via Accessibility and creates an allowlist containing:
    /// 1. HideBar's own process (so the chevron never disappears)
    /// 2. Every item located to the RIGHT of the separator (|)
    /// 3. All non-running apps or items that must stay visible
    private func applyHideBasedOnCoordinates() async {
        logToFile("=== Starting applyHideBasedOnCoordinates ===")
        // If Accessibility is not yet granted, prompt user once
        if !AXIsProcessTrusted() {
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let options = [promptKey: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            logToFile("❌ Failed: AXIsProcessTrusted is false.")
            return
        }
        
        // Take an AX snapshot of the physical menu bar items
        let items = await enumerator.snapshotItems()
        let myBundle = Bundle.main.bundleIdentifier ?? "com.gokul.HideBar"
        
        // Find split threshold from AX items first (exact coordinate space as items)
        let myItems = items.filter { $0.id.bundleID == myBundle }
        var splitThreshold: CGFloat?
        
        // The boundary is the leftmost HideBar control (separator '|' or chevron '>')
        if let boundaryAX = myItems.min(by: { $0.frame.minX < $1.frame.minX }) {
            splitThreshold = boundaryAX.frame.minX
            logToFile("📍 Found boundary item in AX tree at X = \(splitThreshold!) (\(boundaryAX.id.rawValue))")
        }
        
        // Fallback to NSWindow coordinates if AX did not find our buttons
        if splitThreshold == nil {
            if let window = separatorItem.button?.window {
                splitThreshold = window.frame.minX
            } else if let window = expandItem.button?.window {
                splitThreshold = window.frame.minX
            }
        }
        
        let threshold = splitThreshold ?? 0
        logToFile("📍 HideBar split coordinate threshold: X = \(threshold)")
        
        var bundlesToHide = Set<String>()
        var bundlesToKeep = Set<String>()
        var allowedSystemItems = Set(SystemItem.allCases)
        
        // Always whitelist our own bundle so HideBar Ultra's chevron and separator stay visible
        bundlesToKeep.insert(myBundle)
        
        for item in items {
            guard let bundleID = item.id.bundleID, bundleID != myBundle else { continue }
            
            // Check if it's a core system item (Battery, Wi-Fi, Control Center, etc.)
            if let sysItem = MenuBarPolicy.systemItem(for: item.id) {
                if item.frame.midX < threshold {
                    allowedSystemItems.remove(sysItem)
                    logToFile("🙈 Marking System Item for hide: \(sysItem) at x=\(item.frame.minX)...\(item.frame.maxX)")
                    
                    // The keyboard viewer needs its underlying bundle explicitly hidden
                    if sysItem == .keyboard {
                        bundlesToHide.insert("com.apple.TextInputMenuAgent")
                        logToFile("🙈 Marking TextInputMenuAgent for hide")
                    }
                } else {
                    logToFile("👁️ Keeping System Item visible: \(sysItem) at x=\(item.frame.minX)...\(item.frame.maxX)")
                }
                continue // System items are managed by allowedSystemItems, not bundle IDs
            }
            
            // Do not manage system hosts via bundle ID
            if MenuBarPolicy.isUnmanagedAppleBundle(bundleID) {
                logToFile("ℹ️ Skipping unmanaged apple bundle: \(bundleID)")
                continue
            }
            
            // If the item is located to the LEFT of our separator/chevron, it gets hidden!
            if item.frame.midX < threshold {
                bundlesToHide.insert(bundleID)
                logToFile("🙈 Marking for hide: \(bundleID) at x=\(item.frame.minX)...\(item.frame.maxX)")
            } else {
                bundlesToKeep.insert(bundleID)
                logToFile("👁️ Keeping visible: \(bundleID) at x=\(item.frame.minX)...\(item.frame.maxX)")
            }
        }
        
        // Any bundle with an item to the RIGHT of the separator must NEVER be hidden
        bundlesToHide.subtract(bundlesToKeep)
        
        // Build the complete allowlist using both running apps and scanned items
        let runningApps = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        for appBundle in runningApps {
            bundlesToKeep.insert(appBundle)
        }
        
        for item in items {
            if let bundleID = item.id.bundleID {
                bundlesToKeep.insert(bundleID)
            }
        }
        
        // Strictly remove anything marked for hide
        bundlesToKeep.subtract(bundlesToHide)
        
        // Ensure system agent bundles are always kept to prevent breaking system items
        let systemHosts = [
            "com.apple.MenuBarAgent",
            "com.apple.controlcenter",
            "com.apple.screencaptureui",
            "com.apple.systemuiserver"
        ]
        systemHosts.forEach { 
            bundlesToKeep.insert($0)
            bundlesToHide.remove($0)
        }
        
        // Guarantee HideBar itself is never hidden
        bundlesToKeep.insert(myBundle)
        bundlesToKeep.insert("com.gokul.HideBar")
        bundlesToHide.remove(myBundle)
        bundlesToHide.remove("com.gokul.HideBar")
        
        // The TextInputMenuAgent needs its bundle ID kept ONLY if we allow the keyboard system item
        if allowedSystemItems.contains(.keyboard) {
            bundlesToKeep.insert("com.apple.TextInputMenuAgent")
        } else {
            bundlesToKeep.remove("com.apple.TextInputMenuAgent")
        }
        
        logToFile("🎯 Active Allowed Bundles count: \(bundlesToKeep.count)")
        logToFile("🎯 Active Hidden Bundles count: \(bundlesToHide.count)")
        logToFile("🎯 Active Allowed System Items: \(allowedSystemItems)")
        
        // Activate macOS 27 Assessment assertion
        let assertion = AssessmentMode.activate(allowing: Array(allowedSystemItems), bundleIDs: Array(bundlesToKeep)) { error in
            Task { @MainActor in
                if let error = error {
                    self.logToFile("❌ Activation error: \(error)")
                } else {
                    self.logToFile("✅ HideBar assertion active: Selected items hidden!")
                }
            }
        }
        
        self.activeAssertion = assertion
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let toggleTitle = isHidden ? "Show Hidden Icons" : "Hide Icons"
        let toggleMenuItem = NSMenuItem(title: toggleTitle, action: #selector(contextToggle), keyEquivalent: "h")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Preferences...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit HideBar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        expandItem.menu = menu
        expandItem.button?.performClick(nil)
        expandItem.menu = nil 
    }
    
    @objc private func contextToggle() {
        toggle()
    }
    
    @objc func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "HideBar Ultra Preferences"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        self.settingsWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        if let assertion = activeAssertion {
            assertion.invalidate()
        }
        NSApplication.shared.terminate(nil)
    }
}
