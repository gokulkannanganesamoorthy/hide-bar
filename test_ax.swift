import Cocoa

let trusted = AXIsProcessTrusted()
print("Trusted: \(trusted)")

let systemWideElement = AXUIElementCreateSystemWide()
var menuBarValue: CFTypeRef?

let result = AXUIElementCopyAttributeValue(systemWideElement, kAXMenuBarAttribute as CFString, &menuBarValue)
print("Result: \(result.rawValue)")
