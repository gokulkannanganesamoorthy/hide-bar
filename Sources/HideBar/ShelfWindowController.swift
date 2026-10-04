import Cocoa
import SwiftUI

struct HUDContentView: View {
    var isHidden: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 48))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            
            Text(isHidden ? "Hidden" : "Visible")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 180, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
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
    
    func setup() {
        // Setup is handled in showHUD now
    }
    
    func showHUD(isHidden: Bool) {
        let hostingView = NSHostingView(rootView: HUDContentView(isHidden: isHidden))
        panel.contentView = hostingView
        
        guard let screen = NSScreen.main else { return }
        let x = screen.frame.midX - (panel.frame.width / 2)
        let y = screen.frame.midY - (panel.frame.height / 2)
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1.0
        }
        
        // Auto hide HUD after 1 second
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.hide()
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
