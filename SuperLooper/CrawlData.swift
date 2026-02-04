//
//  CrawlData.swift
//  Super Looper
//
//  Data model for bottom crawl - playlist-level setting
//

import Foundation
import SwiftUI

// MARK: - Crawl Data

/// Crawl settings stored at the playlist level
struct CrawlData: Codable, Equatable, Hashable {
    var items: [String]
    var speed: CrawlSpeed
    var backgroundStyle: CrawlBackgroundStyle
    var customBackgroundColor: String  // Hex color for custom style
    var size: CrawlSize
    var isEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case items, speed, backgroundStyle, customBackgroundColor, size, isEnabled
    }
    
    // Custom decoder for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        items = try container.decodeIfPresent([String].self, forKey: .items) ?? []
        speed = try container.decodeIfPresent(CrawlSpeed.self, forKey: .speed) ?? .medium
        backgroundStyle = try container.decodeIfPresent(CrawlBackgroundStyle.self, forKey: .backgroundStyle) ?? .semitransparentDark
        customBackgroundColor = try container.decodeIfPresent(String.self, forKey: .customBackgroundColor) ?? "#333333"
        size = try container.decodeIfPresent(CrawlSize.self, forKey: .size) ?? .standard
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
    }
    
    init(
        items: [String] = [],
        speed: CrawlSpeed = .medium,
        backgroundStyle: CrawlBackgroundStyle = .semitransparentDark,
        customBackgroundColor: String = "#333333",
        size: CrawlSize = .standard,
        isEnabled: Bool = false
    ) {
        self.items = items
        self.speed = speed
        self.backgroundStyle = backgroundStyle
        self.customBackgroundColor = customBackgroundColor
        self.size = size
        self.isEnabled = isEnabled
    }
    
    /// Quick toggle for on/off
    mutating func toggle() {
        isEnabled.toggle()
    }
    
    /// Check if crawl has content to display
    var hasContent: Bool {
        !items.isEmpty && items.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

// MARK: - Crawl Speed

enum CrawlSpeed: String, Codable, CaseIterable, Hashable {
    case slow = "Slow"
    case medium = "Medium"
    case fast = "Fast"
    case veryFast = "Very Fast"
    
    /// Points per second (base rate - will be scaled by view width)
    var basePointsPerSecond: Double {
        switch self {
        case .slow: return 40
        case .medium: return 70
        case .fast: return 100
        case .veryFast: return 140
        }
    }
    
    var icon: String {
        switch self {
        case .slow: return "tortoise"
        case .medium: return "figure.walk"
        case .fast: return "hare"
        case .veryFast: return "bolt"
        }
    }
}

// MARK: - Crawl Size

enum CrawlSize: String, Codable, CaseIterable, Hashable {
    case standard = "Standard"
    case large = "Large (2x)"
    
    /// Multiplier for crawl height
    var multiplier: CGFloat {
        switch self {
        case .standard: return 1.0
        case .large: return 2.0
        }
    }
    
    var icon: String {
        switch self {
        case .standard: return "textformat.size"
        case .large: return "textformat.size.larger"
        }
    }
}

// MARK: - Crawl Background Style

enum CrawlBackgroundStyle: String, Codable, CaseIterable, Hashable {
    case semitransparentDark = "Dark"
    case brandPrimary = "Brand Primary"
    case brandSecondary = "Brand Secondary"
    case brandAccent = "Brand Accent"
    case custom = "Custom"
    
    /// Returns the SwiftUI Color for this background style
    func color(brandSettings: BrandSettings?, customHex: String? = nil) -> Color {
        switch self {
        case .semitransparentDark:
            return Color.black.opacity(0.75)
        case .brandPrimary:
            if let hex = brandSettings?.primaryColor {
                return colorFromHex(hex) ?? Color.blue.opacity(0.85)
            }
            return Color.blue.opacity(0.85)
        case .brandSecondary:
            if let hex = brandSettings?.secondaryColor {
                return colorFromHex(hex) ?? Color.purple.opacity(0.85)
            }
            return Color.purple.opacity(0.85)
        case .brandAccent:
            if let hex = brandSettings?.accentColor {
                return colorFromHex(hex) ?? Color.orange.opacity(0.85)
            }
            return Color.orange.opacity(0.85)
        case .custom:
            if let hex = customHex {
                return colorFromHex(hex) ?? Color.gray.opacity(0.85)
            }
            return Color.gray.opacity(0.85)
        }
    }
    
    /// Helper to convert hex string to Color (private to avoid conflicts)
    private func colorFromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
    
    var icon: String {
        switch self {
        case .semitransparentDark: return "circle.lefthalf.filled"
        case .brandPrimary: return "1.circle"
        case .brandSecondary: return "2.circle"
        case .brandAccent: return "star.circle"
        case .custom: return "paintpalette"
        }
    }
}
