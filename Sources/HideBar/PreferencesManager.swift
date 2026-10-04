import Foundation
import SwiftUI
import Combine

enum IconStyle: String, CaseIterable, Identifiable {
    case chevron = "Chevron ( › / ‹ )"
    case dots = "Dots ( ••• )"
    case line = "Line ( | )"
    case arrows = "Double Arrow ( » / « )"
    
    var id: String { rawValue }
    
    var collapsedIcon: String {
        switch self {
        case .chevron: return "chevron.left"
        case .dots: return "circle.fill"
        case .line: return "minus"
        case .arrows: return "chevron.left.2"
        }
    }
    
    var expandedIcon: String {
        switch self {
        case .chevron: return "chevron.right"
        case .dots: return "circle"
        case .line: return "pipe"
        case .arrows: return "chevron.right.2"
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
    }
}
