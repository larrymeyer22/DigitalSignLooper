//
//  PlaylistInfo.swift
//  Super Looper
//
//  Metadata for a playlist (used in multi-playlist management)
//

import Foundation

/// Represents metadata about a playlist (not the items themselves)
struct PlaylistInfo: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var itemCount: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        itemCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.itemCount = itemCount
    }
    
    /// The folder name for this playlist (sanitized)
    var folderName: String {
        // Use ID to ensure unique folder names
        "\(sanitizedName)_\(id.uuidString.prefix(8))"
    }
    
    /// Sanitized name safe for file system
    private var sanitizedName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        return name
            .components(separatedBy: allowed.inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
            .prefix(30)
            .description
    }
}

// MARK: - Sample Data

extension PlaylistInfo {
    static let sample = PlaylistInfo(
        name: "Trade Show 2024",
        itemCount: 5
    )
    
    static let samples: [PlaylistInfo] = [
        PlaylistInfo(name: "Trade Show 2024", itemCount: 5),
        PlaylistInfo(name: "Product Launch", itemCount: 8),
        PlaylistInfo(name: "Company Overview", itemCount: 3)
    ]
}
