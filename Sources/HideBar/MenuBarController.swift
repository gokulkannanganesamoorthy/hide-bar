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
        if let btn = separatorItem.button {
            btn.title = "|"
            btn.font = NSFont.systemFont(ofSize: 14, weight: .light)
            btn.target = self
            btn.action = #selector(handleSeparatorClick)
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 2. Toggle Control Item (Chevron)
        expandItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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
            logToFile("⚠️ HideBar needs Accessibility permission to calculate icon coordinates.")
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "HideBar needs Accessibility access to find menu bar icons. Please grant it in System Settings > Privacy & Security > Accessibility, then restart HideBar."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Quit")
            
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                NSApplication.shared.terminate(nil)
            } else {
                NSApplication.shared.terminate(nil)
            }
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
        let symbolName = isHidden ? prefs.iconStyle.collapsedIcon : prefs.iconStyle.expandedIcon
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "HideBar Toggle")
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
        
        // Find our separator's horizontal X position on screen
        var separatorX: CGFloat?
        if let window = separatorItem.button?.window {
            let screenFrame = window.convertToScreen(separatorItem.button?.frame ?? .zero)
            separatorX = screenFrame.minX
        }
        
        // Fallback: If separator frame isn't directly measurable via NSWindow, look for our chevron
        if separatorX == nil, let window = expandItem.button?.window {
            let screenFrame = window.convertToScreen(expandItem.button?.frame ?? .zero)
            separatorX = screenFrame.minX
        }
        
        let splitThreshold = separatorX ?? 0
        logToFile("📍 HideBar split coordinate threshold: X = \(splitThreshold)")
        
        var bundlesToHide = Set<String>()
        var bundlesToKeep = Set<String>()
        
        // Always whitelist our own bundle so HideBar Ultra's chevron and separator stay visible
        let myBundle = Bundle.main.bundleIdentifier ?? "com.gokul.HideBar"
        bundlesToKeep.insert(myBundle)
        
        for item in items {
            guard let bundleID = item.id.bundleID, bundleID != myBundle else { continue }
            
            // If the item is located to the LEFT of our separator/chevron, it gets hidden!
            // Note: Menu bar items go from left to right; items with smaller minX are to the left.
            if item.frame.maxX <= splitThreshold {
                bundlesToHide.insert(bundleID)
                logToFile("🙈 Marking for hide: \(bundleID) at x=\(item.frame.minX)...\(item.frame.maxX)")
            } else {
                bundlesToKeep.insert(bundleID)
                logToFile("👁️ Keeping visible: \(bundleID) at x=\(item.frame.minX)...\(item.frame.maxX)")
            }
        }
        
        // If no third-party icons were to the left, fallback to hiding third-party items to the left of the chevron
        if bundlesToHide.isEmpty {
            for item in items {
                guard let bundleID = item.id.bundleID, bundleID != myBundle else { continue }
                if item.frame.minX < splitThreshold {
                    bundlesToHide.insert(bundleID)
                }
            }
        }
        
        // Build the complete allowlist of all running apps minus the ones we explicitly hide
        let runningApps = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        for appBundle in runningApps {
            if !bundlesToHide.contains(appBundle) {
                bundlesToKeep.insert(appBundle)
            }
        }
        
        logToFile("🎯 Active Allowed Bundles count: \(bundlesToKeep.count)")
        logToFile("🎯 Active Hidden Bundles count: \(bundlesToHide.count)")
        logToFile("Allowed bundles: \(bundlesToKeep)")
        logToFile("Hidden bundles: \(bundlesToHide)")
        
        // Activate macOS 27 Assessment assertion
        let assertion = AssessmentMode.activate(bundleIDs: Array(bundlesToKeep)) { error in
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
