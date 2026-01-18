//
//  PlaylistLibraryManager.swift
//  Super Looper
//
//  Manages multiple playlists - create, delete, rename, switch
//

import Foundation
import Observation

/// Manages the library of playlists
@MainActor
@Observable
class PlaylistLibraryManager {
    
    // MARK: - Singleton
    
    static let shared = PlaylistLibraryManager()
    
    // MARK: - Observable Properties
    
    /// All available playlists
    var playlists: [PlaylistInfo] = []
    
    /// Currently selected playlist
    var currentPlaylist: PlaylistInfo?
    
    // MARK: - Private Properties
    
    private let libraryFileName = "playlists_library.json"
    private let fileManager = FileManager.default
    
    // MARK: - Computed Properties
    
    /// URL for the library JSON file
    private var libraryFileURL: URL {
        FileSystemManager.shared.playlistsDirectory.appendingPathComponent(libraryFileName)
    }
    
    // MARK: - Initialization
    
    private init() {
        loadLibrary()
    }
    
    // MARK: - Public Methods
    
    /// Create a new playlist
    @discardableResult
    func createPlaylist(name: String) -> PlaylistInfo {
        let playlist = PlaylistInfo(name: name)
        playlists.append(playlist)
        
        // Create folder structure
        createPlaylistFolders(for: playlist)
        
        // Save library
        saveLibrary()
        
        return playlist
    }
    
    /// Delete a playlist
    func deletePlaylist(_ playlist: PlaylistInfo) {
        // Remove from list
        playlists.removeAll { $0.id == playlist.id }
        
        // Delete folder
        let folderURL = playlistFolderURL(for: playlist)
        try? fileManager.removeItem(at: folderURL)
        
        // Clear current if it was deleted
        if currentPlaylist?.id == playlist.id {
            currentPlaylist = nil
        }
        
        saveLibrary()
    }
    
    /// Rename a playlist
    func renamePlaylist(_ playlist: PlaylistInfo, to newName: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            return
        }
        
        playlists[index].name = newName
        playlists[index].modifiedAt = Date()
        
        if currentPlaylist?.id == playlist.id {
            currentPlaylist = playlists[index]
        }
        
        saveLibrary()
    }
    
    /// Duplicate a playlist
    @discardableResult
    func duplicatePlaylist(_ playlist: PlaylistInfo) -> PlaylistInfo {
        let newPlaylist = PlaylistInfo(
            name: "\(playlist.name) Copy",
            itemCount: playlist.itemCount
        )
        
        playlists.append(newPlaylist)
        
        // Create folder structure
        createPlaylistFolders(for: newPlaylist)
        
        // Copy playlist.json content
        let sourceFolder = playlistFolderURL(for: playlist)
        let destFolder = playlistFolderURL(for: newPlaylist)
        
        let sourcePlaylistFile = sourceFolder.appendingPathComponent("playlist.json")
        let destPlaylistFile = destFolder.appendingPathComponent("playlist.json")
        
        if fileManager.fileExists(atPath: sourcePlaylistFile.path) {
            try? fileManager.copyItem(at: sourcePlaylistFile, to: destPlaylistFile)
        }
        
        // Copy media files
        copyMediaFiles(from: sourceFolder, to: destFolder, subfolder: "Images")
        copyMediaFiles(from: sourceFolder, to: destFolder, subfolder: "Videos")
        
        saveLibrary()
        
        return newPlaylist
    }
    
    /// Select a playlist to use
    func selectPlaylist(_ playlist: PlaylistInfo) {
        currentPlaylist = playlist
        
        // Update FileSystemManager to point to this playlist's folder
        FileSystemManager.shared.currentPlaylistName = playlist.folderName
        FileSystemManager.shared.setupDirectoryStructure()
    }
    
    /// Update item count for a playlist
    func updateItemCount(for playlist: PlaylistInfo, count: Int) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            return
        }
        
        playlists[index].itemCount = count
        playlists[index].modifiedAt = Date()
        
        if currentPlaylist?.id == playlist.id {
            currentPlaylist = playlists[index]
        }
        
        saveLibrary()
    }
    
    /// Get the folder URL for a playlist
    func playlistFolderURL(for playlist: PlaylistInfo) -> URL {
        FileSystemManager.shared.playlistsDirectory.appendingPathComponent(playlist.folderName)
    }
    
    // MARK: - Private Methods
    
    private func createPlaylistFolders(for playlist: PlaylistInfo) {
        let baseURL = playlistFolderURL(for: playlist)
        
        let folders = [
            baseURL,
            baseURL.appendingPathComponent("Videos"),
            baseURL.appendingPathComponent("Images"),
            baseURL.appendingPathComponent("HTML"),
            baseURL.appendingPathComponent("Data")
        ]
        
        for folder in folders {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }
    
    private func copyMediaFiles(from source: URL, to destination: URL, subfolder: String) {
        let sourceDir = source.appendingPathComponent(subfolder)
        let destDir = destination.appendingPathComponent(subfolder)
        
        guard let files = try? fileManager.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            let destFile = destDir.appendingPathComponent(file.lastPathComponent)
            try? fileManager.copyItem(at: file, to: destFile)
        }
    }
    
    // MARK: - Persistence
    
    private func saveLibrary() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(playlists)
            
            // Ensure directory exists
            try? fileManager.createDirectory(
                at: FileSystemManager.shared.playlistsDirectory,
                withIntermediateDirectories: true
            )
            
            try data.write(to: libraryFileURL)
            print("Library saved: \(playlists.count) playlists")
        } catch {
            print("Failed to save library: \(error)")
        }
    }
    
    private func loadLibrary() {
        guard fileManager.fileExists(atPath: libraryFileURL.path) else {
            print("No library file found, starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: libraryFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            playlists = try decoder.decode([PlaylistInfo].self, from: data)
            print("Library loaded: \(playlists.count) playlists")
        } catch {
            print("Failed to load library: \(error)")
        }
    }
}
