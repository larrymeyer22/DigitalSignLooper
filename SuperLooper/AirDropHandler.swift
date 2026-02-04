//
//  AirDropHandler.swift
//  DigitalSignLooper
//
//  Handles incoming AirDrop files and imports them into the active playlist
//

import Foundation
import UIKit
import AVFoundation
import Combine

@MainActor
class AirDropHandler: ObservableObject {
    static let shared = AirDropHandler()
    
    @Published var lastImportedCount: Int = 0
    @Published var lastImportError: String?
    @Published var pendingURLs: [URL] = []
    @Published var showPlaylistPicker: Bool = false
    
    private init() {}
    
    /// Process incoming URLs from AirDrop or other sources
    func handleIncomingURLs(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        
        print("📥 AirDrop: Received \(urls.count) file(s)")
        
        // Get the active playlist manager
        let playlistManager = SharedPlaylistManager.shared.manager
        
        // Check if there's a playlist currently being viewed
        // If currentPlaylist is nil, user is on home screen - show picker
        if playlistManager.currentPlaylist == nil {
            print("📥 AirDrop: On home screen, showing playlist picker")
            pendingURLs = urls
            showPlaylistPicker = true
            return
        }
        
        // Process files with active playlist
        await importFiles(urls, to: playlistManager)
    }
    
    /// Import files to a specific playlist
    func importFiles(_ urls: [URL], to playlistManager: PlaylistManager) async {
        guard let mediaFolder = playlistManager.mediaFolderURL else {
            lastImportError = "Selected playlist is not available."
            return
        }
        
        var importedCount = 0
        var errors: [String] = []
        
        for url in urls {
            // Start accessing security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let result = await importFile(url: url, to: mediaFolder, playlistManager: playlistManager)
            if result.success {
                importedCount += 1
            } else if let error = result.error {
                errors.append("\(url.lastPathComponent): \(error)")
            }
        }
        
        // Update state
        lastImportedCount = importedCount
        
        if !errors.isEmpty {
            lastImportError = errors.joined(separator: "\n")
            print("⚠️ AirDrop: Errors occurred:\n\(lastImportError!)")
        } else {
            lastImportError = nil
        }
        
        if importedCount > 0 {
            playlistManager.savePlaylist()
            print("✅ AirDrop: Imported \(importedCount) file(s)")
        }
        
        // Clear pending files
        pendingURLs = []
    }
    
    /// Import a single file and add to playlist
    private func importFile(url: URL, to mediaFolder: URL, playlistManager: PlaylistManager) async -> (success: Bool, error: String?) {
        let fileExtension = url.pathExtension.lowercased()
        
        // Determine content type
        let contentType = determineContentType(for: fileExtension)
        guard contentType != nil else {
            return (false, "Unsupported file type: .\(fileExtension)")
        }
        
        // Generate unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let baseName = url.deletingPathExtension().lastPathComponent
        let sanitizedName = baseName.replacingOccurrences(of: " ", with: "_")
        let uniqueFilename = "\(sanitizedName)_\(timestamp).\(fileExtension)"
        let destinationURL = mediaFolder.appendingPathComponent(uniqueFilename)
        
        do {
            // Copy file to media folder
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            // Create playlist item based on type
            if let item = await createPlaylistItem(
                filename: uniqueFilename,
                originalName: baseName,
                fileExtension: fileExtension,
                destinationURL: destinationURL,
                playlistManager: playlistManager
            ) {
                playlistManager.addItem(item)
                return (true, nil)
            } else {
                return (false, "Failed to create playlist item")
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    /// Determine content type from file extension
    private func determineContentType(for fileExtension: String) -> String? {
        switch fileExtension {
        case "jpg", "jpeg", "png", "heic":
            return "image"
        case "mp4", "mov", "m4v":
            return "video"
        case "html", "htm":
            return "html"
        default:
            return nil
        }
    }
    
    /// Create a playlist item for the imported file
    private func createPlaylistItem(
        filename: String,
        originalName: String,
        fileExtension: String,
        destinationURL: URL,
        playlistManager: PlaylistManager
    ) async -> PlaylistItem? {
        
        switch fileExtension.lowercased() {
        case "jpg", "jpeg", "png", "heic":
            // Image item
            return PlaylistItem(
                name: originalName,
                contentType: .image(filename: filename),
                duration: 10.0,
                transition: .dissolve,
                transitionDuration: 0.5
            )
            
        case "mp4", "mov", "m4v":
            // Video item - get duration
            let duration = await getVideoDuration(url: destinationURL)
            return PlaylistItem(
                name: originalName,
                contentType: .video(filename: filename),
                duration: duration,
                transition: .dissolve,
                transitionDuration: 0.5
            )
            
        case "html", "htm":
            // HTML file
            return PlaylistItem(
                name: originalName,
                contentType: .customHTML(filename: filename),
                duration: 15.0,
                transition: .dissolve,
                transitionDuration: 0.5
            )
            
        default:
            return nil
        }
    }
    
    /// Get video duration using AVAsset
    private func getVideoDuration(url: URL) async -> Double {
        let asset = AVAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds.isFinite ? seconds : 10.0
        } catch {
            print("⚠️ Could not determine video duration: \(error)")
            return 10.0
        }
    }
}
