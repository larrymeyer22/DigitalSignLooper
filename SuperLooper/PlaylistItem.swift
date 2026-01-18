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
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        contentType: ContentType,
        duration: TimeInterval = 10.0,
        transition: TransitionType = .dissolve
    ) {
        self.id = id
        self.name = name
        self.contentType = contentType
        self.duration = duration
        self.transition = transition
    }
    
    // MARK: - Convenience Initializers
    
    /// Create a video playlist item
    static func video(name: String, filename: String, transition: TransitionType = .dissolve) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .video(filename: filename),
            duration: 0, // Videos play to completion
            transition: transition
        )
    }
    
    /// Create an image playlist item
    static func image(name: String, filename: String, duration: TimeInterval = 10.0, transition: TransitionType = .dissolve) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .image(filename: filename),
            duration: duration,
            transition: transition
        )
    }
    
    /// Create an HTML content playlist item
    static func html(name: String, content: String, duration: TimeInterval = 15.0, transition: TransitionType = .dissolve) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .html(content: content),
            duration: duration,
            transition: transition
        )
    }
    
    /// Create a web URL playlist item
    static func web(name: String, url: URL, duration: TimeInterval = 20.0, transition: TransitionType = .dissolve) -> PlaylistItem {
        PlaylistItem(
            name: name,
            contentType: .web(url: url),
            duration: duration,
            transition: transition
        )
    }
}

// MARK: - Sample Data

extension PlaylistItem {
    /// Sample items for previews and testing
    static let sampleItems: [PlaylistItem] = [
        .image(name: "Welcome Slide", filename: "welcome.jpg", duration: 8),
        .video(name: "Product Demo", filename: "demo.mp4"),
        .image(name: "Features Overview", filename: "features.png", duration: 12),
        .html(name: "Leaderboard", content: "<html><body><h1>Leaderboard</h1></body></html>", duration: 15),
        .web(name: "Company Website", url: URL(string: "https://example.com")!, duration: 20)
    ]
}
