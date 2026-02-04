//
//  PlaylistStorageManager.swift
//  Super Looper
//
//  Handles saving and loading playlists to/from the Files app
//

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

#if canImport(Darwin)
import Darwin
#endif

/// Type alias for compatibility with views using PlaylistInfo
typealias PlaylistInfo = Playlist

/// Manages playlist storage in the Files app
@MainActor
class PlaylistStorageManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PlaylistStorageManager()
    
    // MARK: - Published Properties
    
    @Published var playlists: [Playlist] = []
    @Published var isLoading: Bool = false
    @Published var error: StorageError?
    @Published var currentPlaylist: Playlist?
    
    // MARK: - Constants
    
    /// Root folder name in Documents
    static let rootFolderName = "SuperLooper"
    
    /// Subfolder for playlists
    static let playlistsFolderName = "Playlists"
    
    /// Media subfolder within each playlist
    static let mediaFolderName = "media"
    
    /// Playlist data filename
    static let playlistFilename = "playlist.json"
    
    // MARK: - Initialization
    
    init() {
        setupRootFolder()
        loadPlaylistsSync()
    }
    
    // MARK: - Synchronous Load (for startup)
    
    private func loadPlaylistsSync() {
        // DEBUG: Log where we're looking
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        print("📂 Documents directory: \(docsURL?.path ?? "nil")")
        print("📂 Root folder URL: \(rootFolderURL?.path ?? "nil")")
        print("📂 Playlists folder URL: \(playlistsFolderURL?.path ?? "nil")")
        
        // List everything in Documents to help debug
        if let docsURL = docsURL {
            print("📂 Documents contents:")
            if let contents = try? fm.contentsOfDirectory(atPath: docsURL.path) {
                for item in contents {
                    print("   - \(item)")
                }
            }
        }
        
        var loadedPlaylists: [Playlist] = []
        
        // Try primary location: SuperLooper/Playlists/
        if let playlistsURL = playlistsFolderURL,
           fm.fileExists(atPath: playlistsURL.path) {
            print("📂 Found Playlists folder at: \(playlistsURL.path)")
            loadedPlaylists.append(contentsOf: loadPlaylistsFrom(folder: playlistsURL))
        }
        
        // Try alternate location 1: SuperLooper/ (without Playlists subfolder)
        if let rootURL = rootFolderURL,
           fm.fileExists(atPath: rootURL.path) {
            print("📂 Checking root folder: \(rootURL.path)")
            loadedPlaylists.append(contentsOf: loadPlaylistsFrom(folder: rootURL))
        }
        
        // Try alternate location 2: Documents/ directly
        if let docsURL = docsURL {
            print("📂 Checking Documents folder for playlists")
            loadedPlaylists.append(contentsOf: loadPlaylistsFrom(folder: docsURL))
        }
        
        // Remove duplicates by ID
        var seen = Set<UUID>()
        loadedPlaylists = loadedPlaylists.filter { playlist in
            if seen.contains(playlist.id) {
                return false
            }
            seen.insert(playlist.id)
            return true
        }
        
        print("📂 Total playlists found: \(loadedPlaylists.count)")
        playlists = loadedPlaylists.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    /// Helper to load playlists from a folder (looks for subfolders with playlist.json)
    private func loadPlaylistsFrom(folder: URL) -> [Playlist] {
        let fm = FileManager.default
        var results: [Playlist] = []
        
        guard let contents = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            return results
        }
        
        for itemURL in contents {
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                let playlistFileURL = itemURL.appendingPathComponent(Self.playlistFilename)
                if fm.fileExists(atPath: playlistFileURL.path) {
                    print("   📄 Found playlist.json at: \(playlistFileURL.path)")
                    if let data = try? Data(contentsOf: playlistFileURL) {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        do {
                            let playlist = try decoder.decode(Playlist.self, from: data)
                            print("   ✅ Loaded: \(playlist.name)")
                            results.append(playlist)
                        } catch {
                            print("   ❌ Failed to decode: \(error)")
                        }
                    }
                }
            }
        }
        
        return results
    }
    
    // MARK: - Folder URLs
    
    /// URL to the app's root folder in Documents
    var rootFolderURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(Self.rootFolderName)
    }
    
    /// URL to the Playlists folder
    var playlistsFolderURL: URL? {
        rootFolderURL?.appendingPathComponent(Self.playlistsFolderName)
    }
    
    /// Get the folder URL for a specific playlist
    func folderURL(for playlist: Playlist) -> URL? {
        playlistsFolderURL?.appendingPathComponent(playlist.folderName)
    }
    
    /// Get the media folder URL for a specific playlist
    func mediaFolderURL(for playlist: Playlist) -> URL? {
        folderURL(for: playlist)?.appendingPathComponent(Self.mediaFolderName)
    }
    
    /// Get the playlist.json URL for a specific playlist
    func playlistFileURL(for playlist: Playlist) -> URL? {
        folderURL(for: playlist)?.appendingPathComponent(Self.playlistFilename)
    }
    
    // MARK: - Setup
    
    /// Create root folder structure if needed
    private func setupRootFolder() {
        guard let playlistsURL = playlistsFolderURL else { return }
        
        do {
            try FileManager.default.createDirectory(
                at: playlistsURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            self.error = .setupFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Load Operations
    
    /// Load all playlists from storage
    func loadAllPlaylists() async {
        isLoading = true
        defer { isLoading = false }
        
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        var loadedPlaylists: [Playlist] = []
        
        // Try primary location: SuperLooper/Playlists/
        if let playlistsURL = playlistsFolderURL,
           fm.fileExists(atPath: playlistsURL.path) {
            loadedPlaylists.append(contentsOf: loadPlaylistsFrom(folder: playlistsURL))
        }
        
        // Try alternate location 1: SuperLooper/ (without Playlists subfolder)
        if let rootURL = rootFolderURL,
           fm.fileExists(atPath: rootURL.path) {
            loadedPlaylists.append(contentsOf: loadPlaylistsFrom(folder: rootURL))
        }
        
        // Try alternate location 2: Documents/ directly
        if let docsURL = docsURL {
            loadedPlaylists.append(contentsOf: loadPlaylistsFrom(folder: docsURL))
        }
        
        // Remove duplicates by ID
        var seen = Set<UUID>()
        loadedPlaylists = loadedPlaylists.filter { playlist in
            if seen.contains(playlist.id) {
                return false
            }
            seen.insert(playlist.id)
            return true
        }
        
        // Sort by most recently modified
        playlists = loadedPlaylists.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    /// Load a single playlist from a file URL
    private func loadPlaylist(from url: URL) throws -> Playlist {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Playlist.self, from: data)
    }
    
    // MARK: - Save Operations
    
    /// Save a playlist to storage
    func save(_ playlist: Playlist) async throws {
        guard let folderURL = folderURL(for: playlist),
              let mediaURL = mediaFolderURL(for: playlist),
              let fileURL = playlistFileURL(for: playlist) else {
            throw StorageError.invalidPath
        }
        
        // Create folder structure
        try FileManager.default.createDirectory(
            at: mediaURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Encode and save playlist.json
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(playlist)
        try data.write(to: fileURL, options: .atomic)
        
        // Update local cache
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index] = playlist
        } else {
            playlists.insert(playlist, at: 0)
        }
    }
    
    // MARK: - Delete Operations
    
    /// Delete a playlist and its folder
    func delete(_ playlist: Playlist) async throws {
        guard let folderURL = folderURL(for: playlist) else {
            throw StorageError.invalidPath
        }
        
        try FileManager.default.removeItem(at: folderURL)
        playlists.removeAll { $0.id == playlist.id }
    }
    
    // MARK: - Media File Operations
    
    /// Copy a media file into a playlist's media folder
    func importMediaFile(from sourceURL: URL, to playlist: Playlist, filename: String? = nil) async throws -> String {
        guard let mediaURL = mediaFolderURL(for: playlist) else {
            throw StorageError.invalidPath
        }
        
        // Ensure media folder exists
        try FileManager.default.createDirectory(
            at: mediaURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Determine filename
        let finalFilename = filename ?? sourceURL.lastPathComponent
        let destinationURL = mediaURL.appendingPathComponent(finalFilename)
        
        // Handle filename conflicts
        var uniqueURL = destinationURL
        var counter = 1
        while FileManager.default.fileExists(atPath: uniqueURL.path) {
            let name = destinationURL.deletingPathExtension().lastPathComponent
            let ext = destinationURL.pathExtension
            uniqueURL = mediaURL.appendingPathComponent("\(name)_\(counter).\(ext)")
            counter += 1
        }
        
        // Copy file (need to access security-scoped resource for Files app)
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        try FileManager.default.copyItem(at: sourceURL, to: uniqueURL)
        
        return uniqueURL.lastPathComponent
    }
    
    /// Get the full URL for a media file in a playlist
    func mediaFileURL(filename: String, in playlist: Playlist) -> URL? {
        mediaFolderURL(for: playlist)?.appendingPathComponent(filename)
    }
    
    /// Delete a media file from a playlist's folder
    func deleteMediaFile(filename: String, from playlist: Playlist) throws {
        guard let fileURL = mediaFileURL(filename: filename, in: playlist) else {
            throw StorageError.invalidPath
        }
        
        try FileManager.default.removeItem(at: fileURL)
    }
    
    /// List all media files in a playlist's folder
    func listMediaFiles(in playlist: Playlist) throws -> [URL] {
        guard let mediaURL = mediaFolderURL(for: playlist) else {
            throw StorageError.invalidPath
        }
        
        guard FileManager.default.fileExists(atPath: mediaURL.path) else {
            return []
        }
        
        return try FileManager.default.contentsOfDirectory(
            at: mediaURL,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: .skipsHiddenFiles
        )
    }
    
    /// Get the folder URL for sharing/exporting a playlist
    func exportURL(for playlist: Playlist) -> URL? {
        folderURL(for: playlist)
    }
    
    /// Duplicate a playlist with a new name
    func duplicate(_ playlist: Playlist, newName: String) async throws -> Playlist {
        var newPlaylist = Playlist(
            name: newName,
            description: playlist.description,
            items: playlist.items,
            settings: playlist.settings
        )
        
        // Save the new playlist
        try await save(newPlaylist)
        
        // Copy media files
        if let sourceMediaURL = mediaFolderURL(for: playlist),
           let destMediaURL = mediaFolderURL(for: newPlaylist),
           FileManager.default.fileExists(atPath: sourceMediaURL.path) {
            
            let files = try FileManager.default.contentsOfDirectory(
                at: sourceMediaURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            
            for file in files {
                let destFile = destMediaURL.appendingPathComponent(file.lastPathComponent)
                try FileManager.default.copyItem(at: file, to: destFile)
            }
        }
        
        return newPlaylist
    }
}

// MARK: - Error Types

enum StorageError: LocalizedError {
    case invalidPath
    case setupFailed(String)
    case loadFailed(String)
    case saveFailed(String)
    case fileNotFound(String)
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Invalid file path"
        case .setupFailed(let message):
            return "Setup failed: \(message)"
        case .loadFailed(let message):
            return "Failed to load: \(message)"
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .fileNotFound(let filename):
            return "File not found: \(filename)"
        case .importFailed(let message):
            return "Import failed: \(message)"
        }
    }
}

// MARK: - Convenience Methods for UI

extension PlaylistStorageManager {
    /// Create a new playlist (synchronous wrapper for UI)
    func createPlaylist(name: String) -> Playlist {
        let playlist = Playlist.newPlaylist(name: name)
        Task {
            try? await save(playlist)
        }
        // Add to local list immediately for responsive UI
        playlists.insert(playlist, at: 0)
        return playlist
    }
    
    /// Select a playlist as current
    func selectPlaylist(_ playlist: Playlist) {
        currentPlaylist = playlist
    }
    
    /// Rename a playlist (handles duplicate names by adding suffix)
    func renamePlaylist(_ playlist: Playlist, to newName: String) -> String {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return newName }
        
        // Check for duplicate names (excluding current playlist)
        var finalName = newName
        var counter = 1
        
        while playlists.contains(where: { $0.id != playlist.id && $0.name == finalName }) {
            counter += 1
            finalName = "\(newName) (\(counter))"
        }
        
        var updated = playlists[index]
        updated.name = finalName
        updated.touch()
        playlists[index] = updated
        Task {
            try? await save(updated)
        }
        
        return finalName
    }
    
    /// Delete a playlist
    func deletePlaylist(_ playlist: Playlist) {
        Task {
            try? await delete(playlist)
        }
        playlists.removeAll { $0.id == playlist.id }
    }
    
    /// Update item count (for UI display)
    func updateItemCount(for playlist: Playlist, count: Int) {
        // This is a no-op since items.count is computed from the actual items
        // Kept for compatibility
    }
    
    // MARK: - Export
    
    /// Debug: List all files in Documents directory
    func listAllFiles() {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ No documents directory")
            return
        }
        
        print("📁 Listing all files in Documents:")
        listDirectory(at: docsURL, indent: "")
    }
    
    private func listDirectory(at url: URL, indent: String) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        
        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)
            
            if isDir.boolValue {
                print("\(indent)📂 \(item.lastPathComponent)/")
                listDirectory(at: item, indent: indent + "  ")
            } else {
                let size = (try? fm.attributesOfItem(atPath: item.path)[.size] as? Int) ?? 0
                print("\(indent)📄 \(item.lastPathComponent) (\(size) bytes)")
            }
        }
    }
    
    /// Export a playlist as a zip file for sharing
    /// Returns URL to the zip file
    func exportPlaylist(_ playlist: Playlist) throws -> URL {
        guard let playlistFolder = folderURL(for: playlist),
              let mediaFolder = mediaFolderURL(for: playlist) else {
            throw StorageError.saveFailed("Could not find playlist folder")
        }
        
        let fileManager = FileManager.default
        
        // Debug: List all files so we can see where media is stored
        print("🔍 EXPORT DEBUG - Looking for files for playlist: \(playlist.name)")
        listAllFiles()
        
        // Ensure media folder exists
        try? fileManager.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
        
        // Gather all media files into the playlist's media folder
        try gatherMediaFiles(for: playlist, to: mediaFolder)
        
        // Create temp directory for zip
        let tempDir = fileManager.temporaryDirectory
        let zipFilename = "\(playlist.name.replacingOccurrences(of: " ", with: "_")).zip"
        let zipURL = tempDir.appendingPathComponent(zipFilename)
        
        // Remove existing zip if present
        try? fileManager.removeItem(at: zipURL)
        
        // Use NSFileCoordinator to create zip (iOS built-in)
        var error: NSError?
        var resultURL: URL?
        
        NSFileCoordinator().coordinate(readingItemAt: playlistFolder, options: .forUploading, error: &error) { zippedURL in
            do {
                try fileManager.copyItem(at: zippedURL, to: zipURL)
                resultURL = zipURL
            } catch let copyError {
                print("Failed to copy zip: \(copyError)")
            }
        }
        
        if let error = error {
            throw StorageError.saveFailed(error.localizedDescription)
        }
        
        guard let finalURL = resultURL else {
            throw StorageError.saveFailed("Failed to create export file")
        }
        
        return finalURL
    }
    
    /// Gather all media files referenced by a playlist into its media folder
    private func gatherMediaFiles(for playlist: Playlist, to mediaFolder: URL) throws {
        let fileManager = FileManager.default
        
        // Get documents directory
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        var searchPaths: [URL] = []
        
        // Search ALL playlist folders under Documents/Playlists/
        let playlistsDir = docsURL.appendingPathComponent("Playlists")
        if let playlistFolders = try? fileManager.contentsOfDirectory(at: playlistsDir, includingPropertiesForKeys: nil) {
            for folder in playlistFolders {
                searchPaths.append(folder.appendingPathComponent("Videos"))
                searchPaths.append(folder.appendingPathComponent("Images"))
                searchPaths.append(folder.appendingPathComponent("HTML"))
            }
        }
        
        // Also add SuperLooper paths (new storage system)
        let superLooperDir = docsURL.appendingPathComponent("SuperLooper/Playlists")
        if let slFolders = try? fileManager.contentsOfDirectory(at: superLooperDir, includingPropertiesForKeys: nil) {
            for folder in slFolders {
                searchPaths.append(folder.appendingPathComponent("media"))
            }
        }
        
        // Legacy paths
        searchPaths.append(contentsOf: [
            docsURL.appendingPathComponent("SuperLooper/media"),
            docsURL.appendingPathComponent("videos"),
            docsURL.appendingPathComponent("images"),
            docsURL.appendingPathComponent("media"),
        ])
        
        print("🔍 Searching \(searchPaths.count) paths for media files")
        print("📋 Playlist has \(playlist.items.count) items")
        
        for (index, item) in playlist.items.enumerated() {
            let filenames = item.contentType.referencedFilenames
            print("  Item \(index): \(item.name) - type: \(item.contentType.displayName) - files: \(filenames)")
            
            for filename in filenames {
                let destURL = mediaFolder.appendingPathComponent(filename)
                
                // Skip if already in playlist folder
                if fileManager.fileExists(atPath: destURL.path) {
                    print("✅ \(filename) already in playlist folder")
                    continue
                }
                
                // Search all possible paths
                var found = false
                for searchPath in searchPaths {
                    let sourceURL = searchPath.appendingPathComponent(filename)
                    if fileManager.fileExists(atPath: sourceURL.path) {
                        do {
                            try fileManager.copyItem(at: sourceURL, to: destURL)
                            print("✅ Copied \(filename) from \(searchPath.path)")
                            found = true
                            break
                        } catch {
                            print("⚠️ Failed to copy \(filename): \(error)")
                        }
                    }
                }
                
                if !found {
                    print("❌ Could not find: \(filename)")
                }
            }
        }
    }
    
    // MARK: - Import
    
    /// Import a playlist from a ZIP file
    func importPlaylistFromZip(at zipURL: URL) async throws -> Playlist {
        // On iOS, we can't reliably extract zips programmatically due to sandboxing
        // Instead, tell the user to extract it first
        throw StorageError.importFailed("Please extract the ZIP file first:\n\n1. Open Files app\n2. Tap and hold on the .zip file\n3. Select 'Uncompress'\n4. Then import the uncompressed folder")
    }
    
    /// Import a playlist from a JSON file URL
    /// When user selects playlist.json directly, we only have access to that file
    func importPlaylistFromJSON(at jsonURL: URL) async throws -> Playlist {
        let fileManager = FileManager.default
        guard let playlistsFolder = playlistsFolderURL else {
            throw StorageError.setupFailed("Playlists folder not available")
        }
        
        // Start accessing security-scoped resource
        let accessing = jsonURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                jsonURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Read the JSON file directly
        let data = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var playlist = try decoder.decode(Playlist.self, from: data)
        
        // Use folder name instead of name in JSON
        let folderName = jsonURL.deletingLastPathComponent().lastPathComponent
        let originalName = folderName.isEmpty ? playlist.name : folderName
        
        // Generate new ID and check for name conflicts
        let newId = UUID()
        var newName = originalName
        var counter = 1
        
        while playlists.contains(where: { $0.name == newName }) {
            counter += 1
            newName = "\(originalName) (\(counter))"
        }
        
        playlist = Playlist(
            id: newId,
            name: newName,
            items: playlist.items,
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        // Create destination folder
        let destFolder = playlistsFolder.appendingPathComponent(playlist.folderName)
        let destMediaFolder = destFolder.appendingPathComponent(Self.mediaFolderName)
        try fileManager.createDirectory(at: destMediaFolder, withIntermediateDirectories: true)
        
        // Try to copy media files from the same folder as the JSON
        let sourceFolder = jsonURL.deletingLastPathComponent()
        let sourceMediaFolder = sourceFolder.appendingPathComponent("media")
        
        // We may not have access to sibling files, but try anyway
        if let mediaContents = try? fileManager.contentsOfDirectory(at: sourceMediaFolder, includingPropertiesForKeys: nil) {
            for fileURL in mediaContents {
                let destFile = destMediaFolder.appendingPathComponent(fileURL.lastPathComponent)
                try? fileManager.copyItem(at: fileURL, to: destFile)
            }
        }
        
        // Save playlist.json
        let destPlaylistFile = destFolder.appendingPathComponent(Self.playlistFilename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let newData = try encoder.encode(playlist)
        try newData.write(to: destPlaylistFile)
        
        await loadAllPlaylists()
        return playlist
    }
    
    /// Import a playlist from a folder (user should unzip in Files app first)
    /// Takes a folder URL containing playlist.json and media/
    func importPlaylistFolder(from folderURL: URL) async throws -> Playlist {
        let fileManager = FileManager.default
        guard let playlistsFolder = playlistsFolderURL else {
            throw StorageError.setupFailed("Playlists folder not available")
        }
        
        // Start accessing security-scoped resource if needed
        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Look for playlist.json
        let playlistFile = folderURL.appendingPathComponent(Self.playlistFilename)
        guard fileManager.fileExists(atPath: playlistFile.path) else {
            throw StorageError.loadFailed("No playlist.json found in folder")
        }
        
        // Load playlist
        let data = try Data(contentsOf: playlistFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var playlist = try decoder.decode(Playlist.self, from: data)
        
        // Use folder name instead of name in JSON
        let importedFolderName = folderURL.lastPathComponent
        let originalName = importedFolderName.isEmpty ? playlist.name : importedFolderName
        
        // Generate new ID and check for name conflicts
        let newId = UUID()
        var newName = originalName
        var counter = 1
        
        while playlists.contains(where: { $0.name == newName }) {
            counter += 1
            newName = "\(originalName) (\(counter))"
        }
        
        // Create new playlist with updated info
        playlist = Playlist(
            id: newId,
            name: newName,
            items: playlist.items,
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        // Destination folder
        let destFolder = playlistsFolder.appendingPathComponent(playlist.folderName)
        
        // Copy folder to playlists directory
        try fileManager.copyItem(at: folderURL, to: destFolder)
        
        // Save updated playlist.json with new ID/name
        let newPlaylistFile = destFolder.appendingPathComponent(Self.playlistFilename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let newData = try encoder.encode(playlist)
        try newData.write(to: newPlaylistFile)
        
        // Reload playlists
        await loadAllPlaylists()
        
        return playlist
    }
    
    /// Duplicate a playlist (creates a copy with new ID)
    func duplicatePlaylist(_ playlist: Playlist) async throws -> Playlist {
        guard let sourceFolder = folderURL(for: playlist),
              let playlistsFolder = playlistsFolderURL else {
            throw StorageError.setupFailed("Could not find playlist folder")
        }
        
        let fileManager = FileManager.default
        
        // Create new playlist with new ID and name
        let newId = UUID()
        var newName = "\(playlist.name) Copy"
        var counter = 1
        
        while playlists.contains(where: { $0.name == newName }) {
            counter += 1
            newName = "\(playlist.name) Copy \(counter)"
        }
        
        let newPlaylist = Playlist(
            id: newId,
            name: newName,
            items: playlist.items,
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        // Copy folder
        let destFolder = playlistsFolder.appendingPathComponent(newPlaylist.folderName)
        try fileManager.copyItem(at: sourceFolder, to: destFolder)
        
        // Save updated playlist.json
        let playlistFile = destFolder.appendingPathComponent(Self.playlistFilename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(newPlaylist)
        try data.write(to: playlistFile)
        
        // Reload
        await loadAllPlaylists()
        
        return newPlaylist
    }
}

// MARK: - File Type Helpers

extension PlaylistStorageManager {
    /// Supported video file types
    static let supportedVideoTypes: [UTType] = [.mpeg4Movie, .quickTimeMovie, .movie, .video]
    
    /// Supported image file types
    static let supportedImageTypes: [UTType] = [.png, .jpeg, .heic, .gif, .webP]
    
    /// Supported HTML file types
    static let supportedHTMLTypes: [UTType] = [.html]
    
    /// All supported media types for import
    static var allSupportedTypes: [UTType] {
        supportedVideoTypes + supportedImageTypes + supportedHTMLTypes
    }
}
