//
//  Playlist.swift
//  Super Looper
//
//  Container for a complete playlist with metadata
//  REVISED: Added crawlData as a playlist-level property
//

import Foundation
import SwiftUI  // Required for move(fromOffsets:toOffset:)

/// Represents a complete playlist with metadata and items
struct Playlist: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String?
    var items: [PlaylistItem]
    var createdAt: Date
    var modifiedAt: Date
    
    /// Settings specific to this playlist
    var settings: PlaylistSettings
    
    /// Bottom crawl settings (playlist-level, not a content item)
    var crawlData: CrawlData?
    
    // MARK: - Codable Keys
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, items, createdAt, modifiedAt, settings, crawlData
    }
    
    // MARK: - Custom Decoder (for backwards compatibility)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        items = try container.decodeIfPresent([PlaylistItem].self, forKey: .items) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
        
        // Settings with default fallback for old playlists
        settings = try container.decodeIfPresent(PlaylistSettings.self, forKey: .settings) ?? PlaylistSettings()
        
        // Crawl data is optional
        crawlData = try container.decodeIfPresent(CrawlData.self, forKey: .crawlData)
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        items: [PlaylistItem] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        settings: PlaylistSettings = PlaylistSettings(),
        crawlData: CrawlData? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.items = items
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.settings = settings
        self.crawlData = crawlData
    }
    
    // MARK: - Mutation Helpers
    
    /// Returns a copy with updated modifiedAt timestamp
    mutating func touch() {
        modifiedAt = Date()
    }
    
    /// Add an item and update timestamp
    mutating func addItem(_ item: PlaylistItem) {
        items.append(item)
        touch()
    }
    
    /// Remove an item by ID and update timestamp
    mutating func removeItem(withId id: UUID) {
        items.removeAll { $0.id == id }
        touch()
    }
    
    /// Move an item and update timestamp
    mutating func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        touch()
    }
    
    /// Update an item and timestamp
    mutating func updateItem(_ item: PlaylistItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            touch()
        }
    }
    
    /// Update crawl data and timestamp
    mutating func updateCrawl(_ data: CrawlData) {
        crawlData = data
        touch()
    }
    
    /// Toggle crawl on/off
    mutating func toggleCrawl() {
        if crawlData != nil {
            crawlData?.isEnabled.toggle()
        } else {
            crawlData = CrawlData(isEnabled: true)
        }
        touch()
    }
}

// MARK: - Playlist Settings

/// Settings specific to a playlist
struct PlaylistSettings: Codable, Equatable {
    /// Loop the playlist continuously
    var loopPlayback: Bool
    
    /// Default transition between items (can be overridden per-item)
    var defaultTransition: TransitionType
    
    /// Shuffle playback order
    var shuffleEnabled: Bool
    
    /// Override brand settings with playlist-specific colors
    var useCustomBranding: Bool
    var customPrimaryColor: String?
    var customSecondaryColor: String?
    var customAccentColor: String?
    
    enum CodingKeys: String, CodingKey {
        case loopPlayback, defaultTransition, shuffleEnabled
        case useCustomBranding, customPrimaryColor, customSecondaryColor, customAccentColor
    }
    
    // Custom decoder for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        loopPlayback = try container.decodeIfPresent(Bool.self, forKey: .loopPlayback) ?? true
        defaultTransition = try container.decodeIfPresent(TransitionType.self, forKey: .defaultTransition) ?? .dissolve
        shuffleEnabled = try container.decodeIfPresent(Bool.self, forKey: .shuffleEnabled) ?? false
        useCustomBranding = try container.decodeIfPresent(Bool.self, forKey: .useCustomBranding) ?? false
        customPrimaryColor = try container.decodeIfPresent(String.self, forKey: .customPrimaryColor)
        customSecondaryColor = try container.decodeIfPresent(String.self, forKey: .customSecondaryColor)
        customAccentColor = try container.decodeIfPresent(String.self, forKey: .customAccentColor)
    }
    
    init(
        loopPlayback: Bool = true,
        defaultTransition: TransitionType = .dissolve,
        shuffleEnabled: Bool = false,
        useCustomBranding: Bool = false,
        customPrimaryColor: String? = nil,
        customSecondaryColor: String? = nil,
        customAccentColor: String? = nil
    ) {
        self.loopPlayback = loopPlayback
        self.defaultTransition = defaultTransition
        self.shuffleEnabled = shuffleEnabled
        self.useCustomBranding = useCustomBranding
        self.customPrimaryColor = customPrimaryColor
        self.customSecondaryColor = customSecondaryColor
        self.customAccentColor = customAccentColor
    }
}

// MARK: - Computed Properties

extension Playlist {
    /// Total estimated duration of the playlist
    var totalDuration: TimeInterval {
        items.reduce(0) { total, item in
            // For videos (duration 0), estimate or skip
            total + (item.duration > 0 ? item.duration : 30)
        }
    }
    
    /// Formatted total duration string
    var formattedTotalDuration: String {
        let total = Int(totalDuration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Number of items in the playlist
    var itemCount: Int {
        items.count
    }
    
    /// Summary of content types in the playlist
    var contentTypeSummary: String {
        let types = Set(items.map { $0.contentType.displayName })
        return types.sorted().joined(separator: ", ")
    }
    
    /// Whether crawl is currently active
    var hasCrawlEnabled: Bool {
        crawlData?.isEnabled == true && crawlData?.hasContent == true
    }
    
    /// Folder name for storing this playlist (sanitized)
    var folderName: String {
        // Remove invalid filesystem characters
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let sanitized = name
            .components(separatedBy: invalidChars)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        
        // Ensure we have a valid name
        return sanitized.isEmpty ? id.uuidString : sanitized
    }
}

// MARK: - Sample Data

extension Playlist {
    /// Sample playlist for previews and testing
    static let sample = Playlist(
        name: "Trade Show Demo",
        description: "Product showcase for CES 2026",
        items: PlaylistItem.sampleItems,
        crawlData: CrawlData(
            items: ["Welcome to our booth!", "Ask about our special offers"],
            speed: .medium,
            backgroundStyle: .semitransparentDark,
            isEnabled: false
        )
    )
    
    /// Empty playlist for new creation
    static func newPlaylist(name: String = "New Playlist") -> Playlist {
        Playlist(name: name)
    }
}

// MARK: - Migration Helper

extension Playlist {
    /// Migration helper - can be extended for future format changes
    mutating func migrateIfNeeded() {
        // Currently no migrations needed
        // Crawl is now a playlist-level property via crawlData
    }
}
