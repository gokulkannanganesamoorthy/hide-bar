import Cocoa
import SwiftUI

struct ShelfContentView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    var onToggle: () -> Void
    var onOpenSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "menubar.dock.rectangle")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            Text("HideBar Active")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            
            Divider()
                .frame(height: 14)
            
            Button(action: onToggle) {
                Label("Toggle", systemImage: "arrow.left.and.right")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(6)
            
            Button(action: onOpenSettings) {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .padding(8)
    }
}

@MainActor
class ShelfWindowController: NSWindowController {
    static let shared = ShelfWindowController()
    private var panel: NSPanel!
    
    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 340, height: 50)
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        
        super.init(window: panel)
        self.panel = panel
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(onToggle: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        let hostingView = NSHostingView(
            rootView: ShelfContentView(
                onToggle: onToggle,
                onOpenSettings: onOpenSettings
            )
        )
        panel.contentView = hostingView
    }
    
    func showUnderStatusItem(button: NSStatusBarButton?) {
        guard let button = button, let screen = button.window?.screen ?? NSScreen.main else { return }
        let buttonFrame = button.window?.convertToScreen(button.frame) ?? NSRect.zero
        
        let x = buttonFrame.midX - (panel.frame.width / 2)
        let y = screen.visibleFrame.maxY - panel.frame.height - 4
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1.0
        }
    }
    
    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
            }
        })
    }
}
