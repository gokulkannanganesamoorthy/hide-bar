import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @State private var selectedTab: Tab = .general
    
    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case advanced = "Advanced"
        case help = "Help & Support"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .appearance: return "paintpalette"
            case .advanced: return "hammer"
            case .help: return "questionmark.circle"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("HideBar Ultra")
            .listStyle(.sidebar)
            .frame(minWidth: 150)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralTab(prefs: prefs)
                case .appearance:
                    AppearanceTab(prefs: prefs)
                case .advanced:
                    AdvancedTab(prefs: prefs)
                case .help:
                    HelpTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 650, height: 450)
    }
}

struct GeneralTab: View {
    @ObservedObject var prefs: PreferencesManager
    
    var body: some View {
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
                    
                    Slider(value: $prefs.spacerWidth, in: 100...1200, step: 25)
                    
                    Text("Adjust this until all your desired icons are pushed behind the notch/screen edge. Note: This applies if coordinate hiding is off.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Legacy Hiding (Fallback)")
            }
            
            Section {
                Picker("Auto-Collapse Timer:", selection: $prefs.autoCollapseDelay) {
                    Text("Never (Manual click only)").tag(0.0)
                    Text("After 3 seconds").tag(3.0)
                    Text("After 5 seconds").tag(5.0)
                    Text("After 10 seconds").tag(10.0)
                    Text("After 30 seconds").tag(30.0)
                }
                .font(.system(size: 13))
            } header: {
                Text("Behavior")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

struct AppearanceTab: View {
    @ObservedObject var prefs: PreferencesManager
    
    var body: some View {
        Form {
            Section {
                Picker("Icon Style:", selection: $prefs.iconStyle) {
                    ForEach(IconStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .font(.system(size: 13))
                
                if prefs.iconStyle == .custom {
                    HStack {
                        TextField("Expanded Text (e.g. 🐵):", text: $prefs.customTextExpanded)
                            .frame(maxWidth: 200)
                        TextField("Collapsed Text (e.g. 🙈):", text: $prefs.customTextCollapsed)
                            .frame(maxWidth: 200)
                    }
                    .font(.system(size: 13))
                }
                
                Toggle("Show Separator Line ( | )", isOn: $prefs.showSeparator)
                    .font(.system(size: 13))
            } header: {
                Text("Menu Bar Items")
            } footer: {
                Text("The separator provides a visual boundary. Items to its left will be hidden.")
            }
            
            Section {
                Toggle("Show Floating Shelf when active", isOn: $prefs.showFloatingShelf)
                    .font(.system(size: 13))
            } header: {
                Text("Floating UI")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
    }
}

struct AdvancedTab: View {
    @ObservedObject var prefs: PreferencesManager
    
    var body: some View {
        Form {
            Section {
                Button("View Logs") {
                    let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hidebar_log.txt")
                    NSWorkspace.shared.open(url)
                }
                
                Button("Reset Accessibility Permissions") {
                    let task = Process()
                    task.launchPath = "/usr/bin/tccutil"
                    task.arguments = ["reset", "Accessibility", Bundle.main.bundleIdentifier ?? "com.gokul.HideBar"]
                    try? task.run()
                }
            } header: {
                Text("Troubleshooting")
            } footer: {
                Text("If HideBar isn't hiding apps correctly, check the logs or reset permissions.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced")
    }
}

struct HelpTab: View {
    @State private var showingBugReport = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    stepRow(num: "1", title: "Position HideBar to the right", desc: "Hold ⌘ Command and drag the HideBar chevron to the RIGHT of all icons you want to hide.")
                    stepRow(num: "2", title: "Drag icons to the left of the separator", desc: "Hold ⌘ Command and drag the icons you want to hide to the LEFT of the chevron or separator.")
                    stepRow(num: "3", title: "Click to toggle hide/show", desc: "Click the chevron to hide icons. Click again to reveal them.")
                }
                .padding(.vertical, 8)
            } header: {
                Text("How to use HideBar")
            }
            
            Section {
                Button("Report a Bug / Crash") {
                    showingBugReport = true
                }
                
                Button("Contact Developer") {
                    let url = URL(string: "https://github.com/gokulkannanganesamoorthy/hide-bar")!
                    NSWorkspace.shared.open(url)
                }
            } header: {
                Text("Support")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Help & Support")
        .sheet(isPresented: $showingBugReport) {
            BugReportSheet(isPresented: $showingBugReport)
        }
    }
    
    private func stepRow(num: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue.gradient))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct BugReportSheet: View {
    @Binding var isPresented: Bool
    @State private var logs = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Report a Bug")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                Text("If HideBar crashed or isn't working as expected, you can send us a bug report with your logs.")
                    .font(.subheadline)
                
                Text("Recent Logs:")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                ScrollView {
                    Text(logs.isEmpty ? "No logs found." : logs)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                .frame(height: 150)
                
                HStack {
                    Button("Copy Logs to Clipboard") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(logs, forType: .string)
                    }
                    
                    Spacer()
                    
                    Button("Open GitHub Issue") {
                        let urlString = "https://github.com/your-username/hide-bar/issues/new?title=Bug+Report&body=Describe+the+issue+here...%0A%0A%2A%2ALogs%3A%2A%2A%0A%60%60%60%0A\(logs.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")%0A%60%60%60"
                        if let url = URL(string: urlString) {
                            NSWorkspace.shared.open(url)
                        }
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadLogs()
        }
    }
    
    private func loadLogs() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hidebar_log.txt")
        if let logData = try? String(contentsOf: url, encoding: .utf8) {
            // Get last 2000 characters to avoid huge URLs
            if logData.count > 2000 {
                logs = String(logData.suffix(2000))
            } else {
                logs = logData
            }
        }
    }
}
