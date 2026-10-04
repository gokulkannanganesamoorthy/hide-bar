import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize HideBar Ultra Menu Bar Controller
        MenuBarController.shared.setup()
        
        print("🚀 HideBar Ultra running successfully.")
        print("💡 Tip: Hold ⌘ Command and drag the chevron to position it where you want.")
        print("💡 Right-click the chevron anytime to open Preferences.")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
