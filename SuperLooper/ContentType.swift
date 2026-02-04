//
//  ContentType.swift
//  Super Looper
//
//  Defines all supported content types for playlist items
//
//  ⚠️ CRAWL REMOVED: Crawl is now a playlist-level setting, not a content type.
//  See CrawlData.swift for crawl definitions.
//

import Foundation
import SwiftUI

// MARK: - Content Type Enum

/// All supported content types for playlist items
enum ContentType: Codable, Equatable {
    
    // MARK: Media Files (stored in playlist folder)
    
    /// Video file - plays to completion, ignores duration setting
    case video(filename: String)
    
    /// Image file - displays for specified duration
    case image(filename: String)
    
    /// Custom HTML file imported by user
    case customHTML(filename: String)
    
    // MARK: Live Content
    
    /// Live website URL - displays for specified duration with preloading
    case liveWeb(url: URL, preloadSeconds: TimeInterval)
    
    // MARK: Templates (data stored in JSON, HTML generated on-the-fly)
    
    /// Title slide - simple message display like a PowerPoint title slide
    case titleSlide(data: TitleSlideData)
    
    /// Featured person - employee of the month, award recipient, etc.
    case featuredPerson(data: FeaturedPersonData)
    
    /// Schedule - rotating list of upcoming events
    case schedule(data: ScheduleData)
    
    /// Leaderboard - top 10 ranking display with animations
    case leaderboard(data: LeaderboardData)
    
    /// Countdown timer - counts down to target time or from fixed duration
    case countdown(data: CountdownData)
    
    /// Weather display - shows current conditions and forecast for a location
    case weather(data: WeatherData)
    
    // REMOVED: case crawl(data: CrawlData) - crawl is now a playlist-level setting
    
    // MARK: Legacy Support
    
    /// Inline HTML content (kept for backward compatibility)
    case html(content: String)
    
    /// Basic web URL (legacy - use liveWeb for new items)
    case web(url: URL)
}

// MARK: - Content Type Properties

extension ContentType {
    
    /// Human-readable name for the content type
    var displayName: String {
        switch self {
        case .video: return "Video"
        case .image: return "Image"
        case .customHTML: return "Custom HTML"
        case .liveWeb: return "Live Website"
        case .titleSlide: return "Title Slide"
        case .featuredPerson: return "Featured Person"
        case .schedule: return "Schedule"
        case .leaderboard: return "Leaderboard"
        case .countdown: return "Countdown Timer"
        case .weather: return "Weather"
        case .html: return "HTML Content"
        case .web: return "Website"
        }
    }
    
    /// Alias for displayName (backward compatibility)
    var typeName: String { displayName }
    
    /// SF Symbol icon for the content type
    var iconName: String {
        switch self {
        case .video: return "video.fill"
        case .image: return "photo.fill"
        case .customHTML: return "doc.text.fill"
        case .liveWeb: return "globe"
        case .titleSlide: return "text.badge.star"
        case .featuredPerson: return "person.crop.circle.fill"
        case .schedule: return "calendar"
        case .leaderboard: return "trophy.fill"
        case .countdown: return "timer"
        case .weather: return "cloud.sun.fill"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .web: return "link"
        }
    }
    
    /// Whether this content type can be edited (templates only, not media files)
    var isEditable: Bool {
        switch self {
        case .titleSlide, .featuredPerson, .schedule, .leaderboard, .countdown, .weather, .liveWeb, .customHTML:
            return true
        default:
            return false
        }
    }
    
    /// Whether this content type uses a file stored in the playlist folder
    var usesMediaFile: Bool {
        switch self {
        case .video, .image, .customHTML:
            return true
        case .featuredPerson(let data):
            return data.photoFilename != nil
        default:
            return false
        }
    }
    
    /// All filenames referenced by this content type (for export gathering)
    var referencedFilenames: [String] {
        switch self {
        case .video(let filename):
            return [filename]
        case .image(let filename):
            return [filename]
        case .customHTML(let filename):
            return [filename]
        case .featuredPerson(let data):
            if let photo = data.photoFilename {
                return [photo]
            }
            return []
        default:
            return []
        }
    }
    
    /// Whether this content type generates HTML from template data
    var isTemplate: Bool {
        switch self {
        case .titleSlide, .featuredPerson, .schedule, .leaderboard, .countdown, .weather:
            return true
        default:
            return false
        }
    }
    
    /// Default duration for this content type (0 = play to completion)
    var defaultDuration: TimeInterval {
        switch self {
        case .video: return 0
        case .image: return 10
        case .customHTML: return 15
        case .liveWeb: return 20
        case .titleSlide: return 8
        case .featuredPerson: return 12
        case .schedule: return 30
        case .leaderboard: return 25
        case .countdown: return 60
        case .weather: return 15
        case .html: return 15
        case .web: return 20
        }
    }
    
    /// Whether this content type is a video (plays to completion)
    var isVideo: Bool {
        switch self {
        case .video:
            return true
        default:
            return false
        }
    }
    
    /// Whether this content type is an image
    var isImage: Bool {
        switch self {
        case .image:
            return true
        default:
            return false
        }
    }
    
    /// Whether this content type is a live website
    var isLiveWeb: Bool {
        switch self {
        case .liveWeb, .web:
            return true
        default:
            return false
        }
    }
    
    /// Whether this content type benefits from being pre-rendered (WebViews)
    var needsPreloading: Bool {
        switch self {
        case .titleSlide, .featuredPerson, .schedule, .leaderboard, .liveWeb, .web, .html, .customHTML, .weather:
            return true
        default:
            return false
        }
    }
    
    /// Whether this content type has its own inherent duration (like video files)
    /// True = duration comes from the content itself (videos)
    /// False = duration comes from the playlist item setting (images, templates, etc.)
    var hasFixedDuration: Bool {
        switch self {
        case .video:
            return true   // Videos have their own duration from the file
        default:
            return false  // Everything else uses the item.duration setting
        }
    }
    
    // MARK: - Legacy Crawl Support (for migration)
    
    /// Returns true if this is a crawl content type (for migration purposes)
    /// Always returns false now - crawl is a playlist-level setting
    var isCrawl: Bool {
        return false
    }
    
    /// Extracts crawl data if this is a crawl type (for migration purposes)
    /// Always returns nil now - crawl is a playlist-level setting
    var crawlData: CrawlData? {
        return nil
    }
}

// MARK: - Live Web Data

extension ContentType {
    /// Default preload time for live web content
    static let defaultPreloadSeconds: TimeInterval = 3.0
}

// MARK: - Title Slide Data

/// Data for a simple title/message slide
struct TitleSlideData: Codable, Equatable {
    var headline: String
    var subheadline: String?
    var bodyText: String?
    
    /// If false, allows custom colors for this slide only
    var usesBrandColors: Bool
    var customBackgroundColor: String?  // Hex color
    var customTextColor: String?        // Hex color
    
    init(
        headline: String,
        subheadline: String? = nil,
        bodyText: String? = nil,
        usesBrandColors: Bool = true,
        customBackgroundColor: String? = nil,
        customTextColor: String? = nil
    ) {
        self.headline = headline
        self.subheadline = subheadline
        self.bodyText = bodyText
        self.usesBrandColors = usesBrandColors
        self.customBackgroundColor = customBackgroundColor
        self.customTextColor = customTextColor
    }
}

// MARK: - Featured Person Data

/// Data for featuring a person (employee of the month, award recipient, etc.)
struct FeaturedPersonData: Codable, Equatable {
    var featureTitle: String?        // e.g., "Employee of the Week"
    var name: String
    var title: String               // Job title or role
    var subtitle: String?           // Department, team, etc.
    var photoFilename: String?      // Stored in playlist media folder
    var quote: String?              // Optional quote or message
    var achievements: [String]      // List of achievements/reasons for feature
    
    /// If false, allows custom colors
    var usesBrandColors: Bool
    var customBackgroundColor: String?
    var customTextColor: String?
    var customAccentColor: String?
    
    init(
        featureTitle: String? = nil,
        name: String,
        title: String,
        subtitle: String? = nil,
        photoFilename: String? = nil,
        quote: String? = nil,
        achievements: [String] = [],
        usesBrandColors: Bool = true,
        customBackgroundColor: String? = nil,
        customTextColor: String? = nil,
        customAccentColor: String? = nil
    ) {
        self.featureTitle = featureTitle
        self.name = name
        self.title = title
        self.subtitle = subtitle
        self.photoFilename = photoFilename
        self.quote = quote
        self.achievements = achievements
        self.usesBrandColors = usesBrandColors
        self.customBackgroundColor = customBackgroundColor
        self.customTextColor = customTextColor
        self.customAccentColor = customAccentColor
    }
}

// MARK: - Schedule Data

/// Data for a schedule/agenda display
struct ScheduleData: Codable, Equatable {
    var title: String               // e.g., "Today's Schedule"
    var subtitle: String?           // e.g., "Conference Day 1"
    var events: [ScheduleEvent]
    var displayMode: ScheduleDisplayMode
    var rotationInterval: TimeInterval  // Seconds between rotating events (if rotating mode)
    
    /// If false, allows custom colors
    var usesBrandColors: Bool
    var customBackgroundColor: String?
    var customTextColor: String?
    var customAccentColor: String?
    
    init(
        title: String,
        subtitle: String? = nil,
        events: [ScheduleEvent] = [],
        displayMode: ScheduleDisplayMode = .rotating,
        rotationInterval: TimeInterval = 5,
        usesBrandColors: Bool = true,
        customBackgroundColor: String? = nil,
        customTextColor: String? = nil,
        customAccentColor: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.events = events
        self.displayMode = displayMode
        self.rotationInterval = rotationInterval
        self.usesBrandColors = usesBrandColors
        self.customBackgroundColor = customBackgroundColor
        self.customTextColor = customTextColor
        self.customAccentColor = customAccentColor
    }
}

/// A single event in a schedule
struct ScheduleEvent: Codable, Equatable, Identifiable {
    var id: UUID
    var time: String                // e.g., "9:00 AM", "14:30"
    var title: String               // Event name
    var location: String?           // Room, building, etc.
    var speaker: String?            // Presenter name
    var description: String?        // Additional details
    
    init(
        id: UUID = UUID(),
        time: String,
        title: String,
        location: String? = nil,
        speaker: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.time = time
        self.title = title
        self.location = location
        self.speaker = speaker
        self.description = description
    }
}

/// How the schedule is displayed
enum ScheduleDisplayMode: String, Codable, CaseIterable {
    case rotating       // Cycles through events one at a time
    case list           // Shows all events in a scrolling list
    case grid           // Shows events in a grid layout
}

// MARK: - Leaderboard Data

/// Data for a top-10 style leaderboard
struct LeaderboardData: Codable, Equatable {
    var title: String               // e.g., "Top Performers", "Sales Leaders"
    var subtitle: String?           // e.g., "Q1 2026"
    var entries: [LeaderboardEntry]
    var maxDisplayCount: Int        // How many to show (default 10)
    var animationStyle: LeaderboardAnimation
    var showScores: Bool            // Whether to display numeric scores
    var scoreLabel: String?         // e.g., "points", "sales", "$"
    
    /// If false, allows custom colors
    var usesBrandColors: Bool
    var customBackgroundColor: String?
    var customTextColor: String?
    var customAccentColor: String?
    var customHighlightColor: String?   // For top positions
    
    init(
        title: String,
        subtitle: String? = nil,
        entries: [LeaderboardEntry] = [],
        maxDisplayCount: Int = 10,
        animationStyle: LeaderboardAnimation = .countUp,
        showScores: Bool = true,
        scoreLabel: String? = nil,
        usesBrandColors: Bool = true,
        customBackgroundColor: String? = nil,
        customTextColor: String? = nil,
        customAccentColor: String? = nil,
        customHighlightColor: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.entries = entries
        self.maxDisplayCount = maxDisplayCount
        self.animationStyle = animationStyle
        self.showScores = showScores
        self.scoreLabel = scoreLabel
        self.usesBrandColors = usesBrandColors
        self.customBackgroundColor = customBackgroundColor
        self.customTextColor = customTextColor
        self.customAccentColor = customAccentColor
        self.customHighlightColor = customHighlightColor
    }
    
    /// Returns entries sorted by score (highest first), limited to maxDisplayCount
    var rankedEntries: [LeaderboardEntry] {
        Array(entries.sorted { $0.score > $1.score }.prefix(maxDisplayCount))
    }
}

/// A single entry in a leaderboard
struct LeaderboardEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String                // Team or person name
    var score: Int                  // Numeric score for ranking
    var photoFilename: String?      // Optional avatar/logo
    
    init(
        id: UUID = UUID(),
        name: String,
        score: Int,
        photoFilename: String? = nil
    ) {
        self.id = id
        self.name = name
        self.score = score
        self.photoFilename = photoFilename
    }
}

/// Animation styles for leaderboard reveal
enum LeaderboardAnimation: String, Codable, CaseIterable {
    case countUp            // Scores count up from 0
    case revealBottomToTop  // Reveals from 10th to 1st place
    case revealTopToBottom  // Reveals from 1st to 10th place
    case fadeIn             // Simple fade in all at once
    case slideIn            // Each row slides in from the side
}

// MARK: - Countdown Data

/// Data for countdown timer display
struct CountdownData: Codable, Equatable {
    var title: String?               // Optional title above the timer
    var mode: CountdownMode          // Target time or fixed duration
    var targetDate: Date?            // For .targetTime mode
    var durationHours: Int           // For .duration mode
    var durationMinutes: Int         // For .duration mode
    var durationSeconds: Int         // For .duration mode
    var showDays: Bool               // Whether to show days component
    var showHours: Bool              // Whether to show hours component
    var expiredMessage: String       // Message when countdown reaches zero
    
    /// If false, allows custom colors
    var usesBrandColors: Bool
    var customBackgroundColor: String?
    var customTextColor: String?
    var customAccentColor: String?
    
    init(
        title: String? = nil,
        mode: CountdownMode = .duration,
        targetDate: Date? = nil,
        durationHours: Int = 0,
        durationMinutes: Int = 5,
        durationSeconds: Int = 0,
        showDays: Bool = false,
        showHours: Bool = true,
        expiredMessage: String = "Time's Up!",
        usesBrandColors: Bool = true,
        customBackgroundColor: String? = nil,
        customTextColor: String? = nil,
        customAccentColor: String? = nil
    ) {
        self.title = title
        self.mode = mode
        self.targetDate = targetDate
        self.durationHours = durationHours
        self.durationMinutes = durationMinutes
        self.durationSeconds = durationSeconds
        self.showDays = showDays
        self.showHours = showHours
        self.expiredMessage = expiredMessage
        self.usesBrandColors = usesBrandColors
        self.customBackgroundColor = customBackgroundColor
        self.customTextColor = customTextColor
        self.customAccentColor = customAccentColor
    }
    
    /// Total duration in seconds (for duration mode)
    var totalDurationSeconds: Int {
        durationHours * 3600 + durationMinutes * 60 + durationSeconds
    }
}

/// Countdown mode
enum CountdownMode: String, Codable, CaseIterable {
    case targetTime = "Target Date/Time"
    case duration = "Fixed Duration"
}

// MARK: - Weather Data

/// Data for weather display content
struct WeatherData: Codable, Equatable {
    var locationName: String            // Display name: "San Antonio, TX"
    var latitude: Double                // GPS coordinates for API
    var longitude: Double
    var showForecast: Bool              // Show multi-day forecast strip
    var forecastDays: Int               // Number of forecast days (3-7)
    var temperatureUnit: TemperatureUnit // Fahrenheit or Celsius
    
    /// If false, allows custom colors
    var usesBrandColors: Bool
    var customBackgroundColor: String?
    var customTextColor: String?
    var customAccentColor: String?
    
    init(
        locationName: String = "",
        latitude: Double = 29.7604,      // Default: San Antonio area
        longitude: Double = -98.4936,
        showForecast: Bool = true,
        forecastDays: Int = 5,
        temperatureUnit: TemperatureUnit = .fahrenheit,
        usesBrandColors: Bool = true,
        customBackgroundColor: String? = nil,
        customTextColor: String? = nil,
        customAccentColor: String? = nil
    ) {
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.showForecast = showForecast
        self.forecastDays = forecastDays
        self.temperatureUnit = temperatureUnit
        self.usesBrandColors = usesBrandColors
        self.customBackgroundColor = customBackgroundColor
        self.customTextColor = customTextColor
        self.customAccentColor = customAccentColor
    }
}

/// Temperature unit preference
enum TemperatureUnit: String, Codable, CaseIterable {
    case fahrenheit = "°F"
    case celsius = "°C"
}
