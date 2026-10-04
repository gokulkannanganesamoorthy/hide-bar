import Foundation
import SwiftUI
import Combine

enum IconStyle: String, CaseIterable, Identifiable {
    case chevron = "Chevron ( › / ‹ )"
    case dots = "Dots ( ••• )"
    case line = "Line ( | )"
    case arrows = "Double Arrow ( » / « )"
    case custom = "Custom (Emoji / Text)"
    
    var id: String { rawValue }
    
    var collapsedIcon: String? {
        switch self {
        case .chevron: return "chevron.left"
        case .dots: return "circle.fill"
        case .line: return "minus"
        case .arrows: return "chevron.left.2"
        case .custom: return nil
        }
    }
    
    var expandedIcon: String? {
        switch self {
        case .chevron: return "chevron.right"
        case .dots: return "circle"
        case .line: return "pipe"
        case .arrows: return "chevron.right.2"
        case .custom: return nil
        }
    }
}

@MainActor
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    @Published var spacerWidth: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(spacerWidth), forKey: "spacerWidth")
        }
    }
    
    @Published var autoCollapseDelay: Double {
        didSet {
            UserDefaults.standard.set(autoCollapseDelay, forKey: "autoCollapseDelay")
        }
    }
    
    @Published var iconStyle: IconStyle {
        didSet {
            UserDefaults.standard.set(iconStyle.rawValue, forKey: "iconStyle")
        }
    }
    
    @Published var showFloatingShelf: Bool {
        didSet {
            UserDefaults.standard.set(showFloatingShelf, forKey: "showFloatingShelf")
        }
    }
    
    @Published var showSeparator: Bool {
        didSet {
            UserDefaults.standard.set(showSeparator, forKey: "showSeparator")
        }
    }
    
    @Published var customTextCollapsed: String {
        didSet { UserDefaults.standard.set(customTextCollapsed, forKey: "customTextCollapsed") }
    }
    
    @Published var customTextExpanded: String {
        didSet { UserDefaults.standard.set(customTextExpanded, forKey: "customTextExpanded") }
    }
    
    private init() {
        let storedWidth = UserDefaults.standard.double(forKey: "spacerWidth")
        self.spacerWidth = storedWidth > 0 ? CGFloat(storedWidth) : 600.0
        
        let storedDelay = UserDefaults.standard.double(forKey: "autoCollapseDelay")
        self.autoCollapseDelay = storedDelay > 0 ? storedDelay : 0.0 // 0 means never
        
        if let rawStyle = UserDefaults.standard.string(forKey: "iconStyle"),
           let style = IconStyle(rawValue: rawStyle) {
            self.iconStyle = style
        } else {
            self.iconStyle = .chevron
        }
        
        self.showFloatingShelf = UserDefaults.standard.bool(forKey: "showFloatingShelf")
        
        if UserDefaults.standard.object(forKey: "showSeparator") == nil {
            self.showSeparator = true
        } else {
            self.showSeparator = UserDefaults.standard.bool(forKey: "showSeparator")
        }
        
        self.customTextCollapsed = UserDefaults.standard.string(forKey: "customTextCollapsed") ?? "🙈"
        self.customTextExpanded = UserDefaults.standard.string(forKey: "customTextExpanded") ?? "🐵"
    }
}
