//
//  ContentType.swift
//  Super Looper
//
//  Defines the types of content that can be displayed in a playlist
//

import Foundation

/// Represents the different types of content that can be displayed
enum ContentType: Codable, Equatable {
    case video(filename: String)    // Local video file
    case image(filename: String)    // Local image file
    case html(content: String)      // HTML content as string
    case web(url: URL)              // Live web URL
    
    // MARK: - Convenience Properties
    
    /// Returns a human-readable type name
    var typeName: String {
        switch self {
        case .video: return "Video"
        case .image: return "Image"
        case .html: return "HTML"
        case .web: return "Web"
        }
    }
    
    /// Returns an SF Symbol name for the content type
    var iconName: String {
        switch self {
        case .video: return "video.fill"
        case .image: return "photo.fill"
        case .html: return "doc.richtext.fill"
        case .web: return "globe"
        }
    }
    
    /// Returns true if this content type has a fixed duration (videos play to completion)
    var hasFixedDuration: Bool {
        switch self {
        case .video: return true
        default: return false
        }
    }
    
    /// Returns true if this is a video type
    var isVideo: Bool {
        switch self {
        case .video: return true
        default: return false
        }
    }
}
