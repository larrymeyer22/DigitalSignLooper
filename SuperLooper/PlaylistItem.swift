//
//  PlaylistItem.swift
//  Super Looper
//
//  Core data model for a single item in a playlist
//

import Foundation

/// Represents a single item in a playlist
struct PlaylistItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var contentType: ContentType
    var duration: TimeInterval      // Display duration in seconds (ignored for videos)
    var transition: TransitionType
    var transitionDuration: TimeInterval
    var isHidden: Bool
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        contentType: ContentType,
        duration: TimeInterval = 10.0,
        transition: TransitionType = .dissolve,
        transitionDuration: TimeInterval = 0.5,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.contentType = contentType
        self.duration = duration
        self.transition = transition
        self.transitionDuration = transitionDuration
        self.isHidden = isHidden
    }
    
    // MARK: - Codable (backward compatible)
    
    enum CodingKeys: String, CodingKey {
        case id, name, contentType, duration, transition, transitionDuration, isHidden
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        contentType = try container.decode(ContentType.self, forKey: .contentType)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        transition = try container.decode(TransitionType.self, forKey: .transition)
        transitionDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .transitionDuration) ?? 0.5
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
    }
    
    // MARK: - Convenience Initializers
    
    /// Create a video playlist item
    static func video(name: String, filename: String, transition: TransitionType = .dissolve, transitionDuration: TimeInterval = 0.5) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .video(filename: filename),
            duration: 0.0, // Videos play to completion
            transition: transition,
            transitionDuration: transitionDuration
        )
    }
    
    /// Create an image playlist item
    static func image(name: String, filename: String, duration: TimeInterval = 10.0, transition: TransitionType = .dissolve, transitionDuration: TimeInterval = 0.5) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .image(filename: filename),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
    }
    
    /// Create an HTML content playlist item
    static func html(name: String, content: String, duration: TimeInterval = 15.0, transition: TransitionType = .dissolve, transitionDuration: TimeInterval = 0.5) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .html(content: content),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
    }
    
    /// Create a web URL playlist item
    static func web(name: String, url: URL, duration: TimeInterval = 20.0, transition: TransitionType = .dissolve, transitionDuration: TimeInterval = 0.5) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .web(url: url),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
    }
    
    /// Create a live website playlist item with preloading
    static func liveWeb(name: String, url: URL, duration: TimeInterval = 30.0, preloadSeconds: TimeInterval = 5.0, transition: TransitionType = .dissolve, transitionDuration: TimeInterval = 0.5) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .liveWeb(url: url, preloadSeconds: preloadSeconds),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
    }
    
    /// Create a title slide playlist item
    static func titleSlide(name: String, data: TitleSlideData, duration: TimeInterval = 10.0, transition: TransitionType = .dissolve, transitionDuration: TimeInterval = 0.5) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .titleSlide(data: data),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
    }
    
    /// Create a featured person playlist item
    static func featuredPerson(name: String, data: FeaturedPersonData, duration: TimeInterval = 15.0, transition: TransitionType = .dissolve, transitionDuration: TimeInterval = 0.5) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .featuredPerson(data: data),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
    }
    
    /// Create a schedule playlist item
    static func schedule(name: String, data: ScheduleData, duration: TimeInterval = 30.0, transition: TransitionType = .dissolve, transitionDuration: TimeInterval = 0.5) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .schedule(data: data),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
    }
    
    /// Create a leaderboard playlist item
    static func leaderboard(name: String, data: LeaderboardData, duration: TimeInterval = 25.0, transition: TransitionType = .dissolve, transitionDuration: TimeInterval = 0.5) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .leaderboard(data: data),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
    }
    
    /// Create a custom HTML playlist item
    static func customHTML(name: String, filename: String, duration: TimeInterval = 15.0, transition: TransitionType = .dissolve, transitionDuration: TimeInterval = 0.5) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .customHTML(filename: filename),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
    }
}

// MARK: - Sample Data

extension PlaylistItem {
    /// Sample items for previews and testing
    static let sampleItems: [PlaylistItem] = [
        .image(name: "Welcome Slide", filename: "welcome.jpg", duration: 8.0),
        .video(name: "Product Demo", filename: "demo.mp4"),
        .image(name: "Features Overview", filename: "features.png", duration: 12.0),
        .html(name: "Leaderboard", content: "<html><body><h1>Leaderboard</h1></body></html>", duration: 15.0),
        .web(name: "Company Website", url: URL(string: "https://example.com")!, duration: 20.0)
    ]
}
