//
//  BrandSettings.swift
//  Super Looper
//
//  Global brand settings for generated content templates
//

import SwiftUI
import Combine

// MARK: - Brand Settings Model

/// Global brand settings used by content templates
struct BrandSettings: Codable, Equatable {
    
    // MARK: - Nested Types (must be defined before properties that use them)
    
    enum FontWeight: String, Codable, CaseIterable, Equatable {
        case thin = "Thin"
        case light = "Light"
        case regular = "Regular"
        case medium = "Medium"
        case semibold = "Semibold"
        case bold = "Bold"
        case heavy = "Heavy"
        case black = "Black"
        
        var cssValue: String {
            switch self {
            case .thin: return "100"
            case .light: return "300"
            case .regular: return "400"
            case .medium: return "500"
            case .semibold: return "600"
            case .bold: return "700"
            case .heavy: return "800"
            case .black: return "900"
            }
        }
        
        var swiftUIWeight: Font.Weight {
            switch self {
            case .thin: return .thin
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            case .black: return .black
            }
        }
    }
    
    enum FontFamily: String, Codable, CaseIterable, Equatable {
        case system = "System (San Francisco)"
        case helvetica = "Helvetica Neue"
        case arial = "Arial"
        case avenir = "Avenir"
        case futura = "Futura"
        case georgia = "Georgia"
        case palatino = "Palatino"
        case times = "Times New Roman"
        case courier = "Courier"
        case menlo = "Menlo"
        
        var cssValue: String {
            switch self {
            case .system: return "-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif"
            case .helvetica: return "'Helvetica Neue', Helvetica, sans-serif"
            case .arial: return "Arial, Helvetica, sans-serif"
            case .avenir: return "Avenir, 'Avenir Next', sans-serif"
            case .futura: return "Futura, 'Futura PT', sans-serif"
            case .georgia: return "Georgia, 'Times New Roman', serif"
            case .palatino: return "Palatino, 'Palatino Linotype', serif"
            case .times: return "'Times New Roman', Times, serif"
            case .courier: return "'Courier New', Courier, monospace"
            case .menlo: return "Menlo, Monaco, monospace"
            }
        }
        
        var isSerif: Bool {
            switch self {
            case .georgia, .palatino, .times: return true
            default: return false
            }
        }
        
        var isMonospace: Bool {
            switch self {
            case .courier, .menlo: return true
            default: return false
            }
        }
    }
    
    enum LogoPlacement: String, Codable, CaseIterable, Equatable {
        case topLeft = "Top Left"
        case topRight = "Top Right"
        case bottomLeft = "Bottom Left"
        case bottomRight = "Bottom Right"
        case none = "Hidden"
        
        var icon: String {
            switch self {
            case .topLeft: return "arrow.up.left.square"
            case .topRight: return "arrow.up.right.square"
            case .bottomLeft: return "arrow.down.left.square"
            case .bottomRight: return "arrow.down.right.square"
            case .none: return "eye.slash"
            }
        }
        
        /// CSS positioning values
        var cssPosition: (top: String?, bottom: String?, left: String?, right: String?) {
            switch self {
            case .topLeft: return ("2%", nil, "2%", nil)
            case .topRight: return ("2%", nil, nil, "2%")
            case .bottomLeft: return (nil, "2%", "2%", nil)
            case .bottomRight: return (nil, "2%", nil, "2%")
            case .none: return (nil, nil, nil, nil)
            }
        }
    }
    
    // MARK: - Properties
    
    // Colors (stored as hex strings)
    var primaryColor: String
    var secondaryColor: String
    var accentColor: String
    var backgroundColor: String
    var textColor: String
    var subtitleColor: String
    
    // Typography
    var titleFont: FontFamily
    var bodyFont: FontFamily
    var titleFontWeight: FontWeight
    var bodyFontWeight: FontWeight
    
    // Logos (stored as base64 or filename)
    var leftLogoData: String?
    var rightLogoData: String?
    var leftLogoFilename: String?
    var rightLogoFilename: String?
    
    // Logo placement options
    var logo1Placement: LogoPlacement
    var logo2Placement: LogoPlacement
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case primaryColor, secondaryColor, accentColor, backgroundColor, textColor, subtitleColor
        case titleFont, bodyFont, titleFontWeight, bodyFontWeight
        case leftLogoData, rightLogoData, leftLogoFilename, rightLogoFilename
        case logo1Placement, logo2Placement
    }
    
    // MARK: - Initializers
    
    init(
        primaryColor: String = "#CC0000",
        secondaryColor: String = "#8B0000",
        accentColor: String = "#CC0000",
        backgroundColor: String = "#1A1A1A",
        textColor: String = "#FFFFFF",
        subtitleColor: String = "#CCCCCC",
        titleFont: FontFamily = .system,
        bodyFont: FontFamily = .system,
        titleFontWeight: FontWeight = .bold,
        bodyFontWeight: FontWeight = .regular,
        leftLogoData: String? = nil,
        rightLogoData: String? = nil,
        leftLogoFilename: String? = nil,
        rightLogoFilename: String? = nil,
        logo1Placement: LogoPlacement = .topLeft,
        logo2Placement: LogoPlacement = .topRight
    ) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.subtitleColor = subtitleColor
        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.titleFontWeight = titleFontWeight
        self.bodyFontWeight = bodyFontWeight
        self.leftLogoData = leftLogoData
        self.rightLogoData = rightLogoData
        self.leftLogoFilename = leftLogoFilename
        self.rightLogoFilename = rightLogoFilename
        self.logo1Placement = logo1Placement
        self.logo2Placement = logo2Placement
    }
    
    // Custom decoder for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        primaryColor = try container.decodeIfPresent(String.self, forKey: .primaryColor) ?? "#0066CC"
        secondaryColor = try container.decodeIfPresent(String.self, forKey: .secondaryColor) ?? "#FF6B35"
        accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor) ?? "#FFD700"
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor) ?? "#1A1A2E"
        textColor = try container.decodeIfPresent(String.self, forKey: .textColor) ?? "#FFFFFF"
        subtitleColor = try container.decodeIfPresent(String.self, forKey: .subtitleColor) ?? "#CCCCCC"
        titleFont = try container.decodeIfPresent(FontFamily.self, forKey: .titleFont) ?? .system
        bodyFont = try container.decodeIfPresent(FontFamily.self, forKey: .bodyFont) ?? .system
        titleFontWeight = try container.decodeIfPresent(FontWeight.self, forKey: .titleFontWeight) ?? .bold
        bodyFontWeight = try container.decodeIfPresent(FontWeight.self, forKey: .bodyFontWeight) ?? .regular
        leftLogoData = try container.decodeIfPresent(String.self, forKey: .leftLogoData)
        rightLogoData = try container.decodeIfPresent(String.self, forKey: .rightLogoData)
        leftLogoFilename = try container.decodeIfPresent(String.self, forKey: .leftLogoFilename)
        rightLogoFilename = try container.decodeIfPresent(String.self, forKey: .rightLogoFilename)
        logo1Placement = try container.decodeIfPresent(LogoPlacement.self, forKey: .logo1Placement) ?? .topLeft
        logo2Placement = try container.decodeIfPresent(LogoPlacement.self, forKey: .logo2Placement) ?? .topRight
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(primaryColor, forKey: .primaryColor)
        try container.encode(secondaryColor, forKey: .secondaryColor)
        try container.encode(accentColor, forKey: .accentColor)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(textColor, forKey: .textColor)
        try container.encode(subtitleColor, forKey: .subtitleColor)
        try container.encode(titleFont, forKey: .titleFont)
        try container.encode(bodyFont, forKey: .bodyFont)
        try container.encode(titleFontWeight, forKey: .titleFontWeight)
        try container.encode(bodyFontWeight, forKey: .bodyFontWeight)
        try container.encodeIfPresent(leftLogoData, forKey: .leftLogoData)
        try container.encodeIfPresent(rightLogoData, forKey: .rightLogoData)
        try container.encodeIfPresent(leftLogoFilename, forKey: .leftLogoFilename)
        try container.encodeIfPresent(rightLogoFilename, forKey: .rightLogoFilename)
        try container.encode(logo1Placement, forKey: .logo1Placement)
        try container.encode(logo2Placement, forKey: .logo2Placement)
    }
    
    // MARK: - Color Helpers
    
    func color(from hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    var primarySwiftUIColor: Color { color(from: primaryColor) }
    var secondarySwiftUIColor: Color { color(from: secondaryColor) }
    var accentSwiftUIColor: Color { color(from: accentColor) }
    var backgroundSwiftUIColor: Color { color(from: backgroundColor) }
    var textSwiftUIColor: Color { color(from: textColor) }
    var subtitleSwiftUIColor: Color { color(from: subtitleColor) }
    
    // MARK: - CSS Font Helpers
    
    var titleFontCSS: String { titleFont.cssValue }
    var bodyFontCSS: String { bodyFont.cssValue }
    var titleWeightCSS: String { titleFontWeight.cssValue }
    var bodyWeightCSS: String { bodyFontWeight.cssValue }
    
    var settingsHash: String {
        "\(backgroundColor)\(textColor)\(accentColor)\(subtitleColor)\(titleFont.rawValue)\(bodyFont.rawValue)\(titleFontWeight.rawValue)\(bodyFontWeight.rawValue)"
    }
    
    // MARK: - Logo Helpers
    
    var leftLogoImage: UIImage? {
        guard let data = leftLogoData,
              let imageData = Data(base64Encoded: data) else { return nil }
        return UIImage(data: imageData)
    }
    
    var rightLogoImage: UIImage? {
        guard let data = rightLogoData,
              let imageData = Data(base64Encoded: data) else { return nil }
        return UIImage(data: imageData)
    }
    
    // MARK: - CSS Generation
    
    var cssVariables: String {
        """
        :root {
            --primary-color: \(primaryColor);
            --secondary-color: \(secondaryColor);
            --accent-color: \(accentColor);
            --background-color: \(backgroundColor);
            --text-color: \(textColor);
            --subtitle-color: \(subtitleColor);
            --title-font: \(titleFont.cssValue);
            --body-font: \(bodyFont.cssValue);
            --title-font-weight: \(titleFontWeight.cssValue);
            --body-font-weight: \(bodyFontWeight.cssValue);
        }
        """
    }
}

// MARK: - Preset Themes

extension BrandSettings {
    static let presets: [String: BrandSettings] = [
        "Corporate Blue": BrandSettings(
            primaryColor: "#0066CC",
            secondaryColor: "#003366",
            accentColor: "#FFD700",
            backgroundColor: "#1A1A2E",
            textColor: "#FFFFFF",
            subtitleColor: "#B8B8B8"
        ),
        "Modern Dark": BrandSettings(
            primaryColor: "#6C63FF",
            secondaryColor: "#3D3D3D",
            accentColor: "#00D9FF",
            backgroundColor: "#121212",
            textColor: "#FFFFFF",
            subtitleColor: "#888888"
        ),
        "Vibrant": BrandSettings(
            primaryColor: "#FF6B35",
            secondaryColor: "#F7C59F",
            accentColor: "#EFEFD0",
            backgroundColor: "#004E89",
            textColor: "#FFFFFF",
            subtitleColor: "#A8D0E6"
        ),
        "Nature": BrandSettings(
            primaryColor: "#2D6A4F",
            secondaryColor: "#40916C",
            accentColor: "#95D5B2",
            backgroundColor: "#081C15",
            textColor: "#D8F3DC",
            subtitleColor: "#74C69D"
        ),
        "Red & Black": BrandSettings(
            primaryColor: "#CC0000",
            secondaryColor: "#8B0000",
            accentColor: "#CC0000",
            backgroundColor: "#1A1A1A",
            textColor: "#FFFFFF",
            subtitleColor: "#CCCCCC"
        ),
        "Navy & Lime": BrandSettings(
            primaryColor: "#001F5C",
            secondaryColor: "#003380",
            accentColor: "#32CD32",
            backgroundColor: "#001F5C",
            textColor: "#FFFFFF",
            subtitleColor: "#B8D4E8"
        )
    ]
}

// MARK: - Brand Settings Manager

@MainActor
class BrandSettingsManager: ObservableObject {
    
    static let shared = BrandSettingsManager()
    
    @Published var settings: BrandSettings
    
    private let userDefaultsKey = "SuperLooper.BrandSettings"
    private var observer: NSObjectProtocol?
    
    init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode(BrandSettings.self, from: data) {
            self.settings = saved
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            self.settings = BrandSettings()
        }
        
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reloadIfNeeded()
            }
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func reloadIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let saved = try? JSONDecoder().decode(BrandSettings.self, from: data) else { return }
        
        if saved != settings {
            settings = saved
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.synchronize()
        settings = BrandSettings()
        save()
    }
    
    func uploadLogo(image: UIImage, position: LogoPosition) {
        guard let data = image.pngData() else { return }
        let base64 = data.base64EncodedString()
        
        switch position {
        case .left:
            settings.leftLogoData = base64
        case .right:
            settings.rightLogoData = base64
        }
        save()
    }
    
    func removeLogo(position: LogoPosition) {
        switch position {
        case .left:
            settings.leftLogoData = nil
            settings.leftLogoFilename = nil
        case .right:
            settings.rightLogoData = nil
            settings.rightLogoFilename = nil
        }
        save()
    }
    
    enum LogoPosition {
        case left, right
    }
}
