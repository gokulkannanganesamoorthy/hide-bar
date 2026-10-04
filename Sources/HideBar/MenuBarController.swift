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
    
    // Asynchronous item enumerator that reads MenuBarAgent via Accessibility
    private let enumerator = ItemEnumerator()
    
    // Floating cover windows for bruteforce hiding
    private var coverWindows: [NSWindow] = []
    
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
            showCoverWindows()
            ShelfWindowController.shared.hide()
        } else {
            hideCoverWindows()
            
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
    
    private func showCoverWindows() {
        hideCoverWindows()
        
        guard let buttonWindow = separatorItem.button?.window,
              let screen = buttonWindow.screen else { return }
        
        // Find the absolute right edge of the separator on the screen
        let maxX = buttonWindow.convertToScreen(separatorItem.button?.frame ?? .zero).maxX
        
        Task { @MainActor in
            let items = await enumerator.snapshotItems()
            var minX = maxX
            
            for item in items {
                // Ignore our own items and the Apple/App menus by assuming status items are mostly contiguous from the right
                if item.frame.maxX <= maxX {
                    if item.frame.minX < minX && item.frame.minX > (screen.frame.width * 0.25) {
                        minX = item.frame.minX
                    }
                }
            }
            
            // Add a small padding
            minX -= 10
            if minX >= maxX { return } // Nothing to cover
            
            let menuBarHeight = NSStatusBar.system.thickness
            let frame = NSRect(x: minX, y: screen.visibleFrame.maxY, width: maxX - minX, height: menuBarHeight)
            
            let win = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            win.level = .statusBar + 1
            win.backgroundColor = .clear
            win.isOpaque = false
            win.hasShadow = false
            win.ignoresMouseEvents = false // Block clicks to hidden items
            win.collectionBehavior = [.transient, .ignoresCycle] // Hide in fullscreen
            
            let blur = NSVisualEffectView(frame: win.contentView!.bounds)
            blur.autoresizingMask = [.width, .height]
            blur.material = .headerView // Best match for menu bar
            blur.state = .active
            blur.blendingMode = .behindWindow
            win.contentView = blur
            
            win.setFrame(frame, display: true)
            win.orderFront(nil)
            self.coverWindows.append(win)
        }
    }
    
    private func hideCoverWindows() {
        for win in coverWindows {
            win.orderOut(nil)
        }
        coverWindows.removeAll()
    }
    
    /// Production-grade coordinate calculation:
    /// Scans all menu bar items via Accessibility and creates an allowlist containing:
    /// 1. HideBar's own process (so the chevron never disappears)
    /// 2. Every item located to the RIGHT of the separator (|)
    /// 3. All non-running apps or items that must stay visible
    // Replaced by showCoverWindows()
    
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
        hideCoverWindows()
        NSApplication.shared.terminate(nil)
    }
}
