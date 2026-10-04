import SwiftUI

struct SettingsView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("HideBar Ultra")
                        .font(.system(size: 16, weight: .bold))
                    Text("macOS 27 Optimized Menu Bar Manager")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("General").tag(0)
                Text("Appearance").tag(1)
                Text("How to Use").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(16)
            
            // Content
            Group {
                if selectedTab == 0 {
                    generalTab
                } else if selectedTab == 1 {
                    appearanceTab
                } else {
                    howToUseTab
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            Spacer()
            
            Divider()
            
            // Footer
            HStack {
                Text("Version 2.0 (macOS 27 Ready)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 480, height: 440)
    }
    
    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Hide Distance (Spacer Width):")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Int(prefs.spacerWidth)) px")
                            .monospacedDigit()
                            .foregroundColor(.cyan)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    
                    Slider(value: $prefs.spacerWidth, in: 100...1200, step: 25) {
                        Text("Width")
                    }
                    
                    Text("Adjust this until all your desired icons are pushed behind the notch/screen edge.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Divider().padding(.vertical, 6)
            
            Section {
                Picker("Auto-Collapse Timer:", selection: $prefs.autoCollapseDelay) {
                    Text("Never (Manual click only)").tag(0.0)
                    Text("After 3 seconds").tag(3.0)
                    Text("After 5 seconds").tag(5.0)
                    Text("After 10 seconds").tag(10.0)
                    Text("After 30 seconds").tag(30.0)
                }
                .font(.system(size: 13))
            }
            
            Divider().padding(.vertical, 6)
            
            Section {
                Toggle("Show Floating Shelf when active", isOn: $prefs.showFloatingShelf)
                    .font(.system(size: 13))
                Text("Displays a floating glassmorphic control shelf under the menu bar.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Appearance Tab
    private var appearanceTab: some View {
        Form {
            Section {
                Picker("Icon Style:", selection: $prefs.iconStyle) {
                    ForEach(IconStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .font(.system(size: 13))
            }
            
            Divider().padding(.vertical, 8)
            
            Section {
                Toggle("Show Separator Line ( | )", isOn: $prefs.showSeparator)
                    .font(.system(size: 13))
                Text("The separator gives you a visual boundary to drop icons next to.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - How to Use Tab
    private var howToUseTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to organize your Menu Bar:")
                .font(.system(size: 13, weight: .bold))
            
            VStack(alignment: .leading, spacing: 8) {
                stepRow(
                    num: "1",
                    title: "Position HideBar to the right",
                    desc: "Hold ⌘ Command and drag the HideBar chevron to the RIGHT of all icons you want to hide (place it near your Battery/Clock)."
                )
                stepRow(
                    num: "2",
                    title: "Drag icons to the left of the separator",
                    desc: "Hold ⌘ Command and drag the icons you want to hide to the LEFT of the chevron or separator."
                )
                stepRow(
                    num: "3",
                    title: "Click to toggle hide/show",
                    desc: "Click the chevron to hide icons. Click again to reveal them. Right-click anytime for Settings."
                )
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private func stepRow(num: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
