//
//  TransitionType.swift
//  Super Looper
//
//  Defines transition styles between playlist items
//

import Foundation

/// Represents the transition effect when moving between playlist items
enum TransitionType: String, Codable, CaseIterable {
    case cut = "cut"           // Instant switch
    case fade = "fade"         // Fade through black
    case dissolve = "dissolve" // Cross-dissolve
    
    /// Human-readable name for the transition
    var displayName: String {
        switch self {
        case .cut: return "Cut"
        case .fade: return "Fade"
        case .dissolve: return "Dissolve"
        }
    }
    
    /// Description of the transition effect
    var description: String {
        switch self {
        case .cut: return "Instant switch with no animation"
        case .fade: return "Fade out to black, then fade in"
        case .dissolve: return "Cross-dissolve between items"
        }
    }
}
