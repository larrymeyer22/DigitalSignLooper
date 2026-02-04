//
//  TransitionType.swift
//  Super Looper
//
//  Defines transition styles between playlist items
//

import Foundation

/// Represents the transition effect when moving between playlist items
enum TransitionType: String, Codable, CaseIterable {
    case cut = "cut"             // Instant switch, no animation
    case dissolve = "dissolve"   // Cross-dissolve (opacity fade)
    case pushLeft = "pushLeft"   // New content pushes from right, old exits left
    case pushRight = "pushRight" // New content pushes from left, old exits right
    case fade = "fade"           // Legacy — treated as dissolve
    
    /// Cases shown in UI pickers (excludes legacy)
    static var availableCases: [TransitionType] {
        [.cut, .dissolve, .pushLeft, .pushRight]
    }
    
    /// Human-readable name
    var displayName: String {
        switch self {
        case .cut: return "Cut"
        case .dissolve: return "Dissolve"
        case .pushLeft: return "Push Left"
        case .pushRight: return "Push Right"
        case .fade: return "Dissolve"  // Legacy label
        }
    }
    
    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .cut: return "scissors"
        case .dissolve: return "circle.dotted"
        case .pushLeft: return "arrow.left.square"
        case .pushRight: return "arrow.right.square"
        case .fade: return "circle.dotted"
        }
    }
    
    /// Description text for UI
    var description: String {
        switch self {
        case .cut: return "Instant switch with no animation"
        case .dissolve: return "Cross-dissolve between items"
        case .pushLeft: return "New content pushes in from the right"
        case .pushRight: return "New content pushes in from the left"
        case .fade: return "Cross-dissolve between items"
        }
    }
    
    /// Normalize legacy cases to their modern equivalent
    var normalized: TransitionType {
        self == .fade ? .dissolve : self
    }
}
