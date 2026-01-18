//
//  FileSystemManager.swift
//  Super Looper
//
//  Manages file system operations for playlist content
//

import Foundation
import UIKit

/// Manages file system operations for storing and retrieving playlist content
class FileSystemManager {
    
    // MARK: - Singleton
    
    static let shared = FileSystemManager()
    
    // MARK: - Properties
    
    /// Base directory for all playlists
    private let playlistsDirectoryName = "Playlists"
    
    /// Current playlist name (will be set when loading a playlist)
    var currentPlaylistName: String = "Default"
    
    // MARK: - Directory URLs
    
    /// Documents directory
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Base playlists directory
    var playlistsDirectory: URL {
        documentsDirectory.appendingPathComponent(playlistsDirectoryName)
    }
    
    /// Current playlist directory
    var currentPlaylistDirectory: URL {
        playlistsDirectory.appendingPathComponent(currentPlaylistName)
    }
    
    /// Videos folder for current playlist
    var videosDirectory: URL {
        currentPlaylistDirectory.appendingPathComponent("Videos")
    }
    
    /// Images folder for current playlist
    var imagesDirectory: URL {
        currentPlaylistDirectory.appendingPathComponent("Images")
    }
    
    /// HTML folder for current playlist
    var htmlDirectory: URL {
        currentPlaylistDirectory.appendingPathComponent("HTML")
    }
    
    /// Data folder for current playlist
    var dataDirectory: URL {
        currentPlaylistDirectory.appendingPathComponent("Data")
    }
    
    /// Playlist JSON file
    var playlistFileURL: URL {
        currentPlaylistDirectory.appendingPathComponent("playlist.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        setupDirectoryStructure()
    }
    
    // MARK: - Directory Setup
    
    /// Creates the directory structure for the current playlist
    func setupDirectoryStructure() {
        let directories = [
            playlistsDirectory,
            currentPlaylistDirectory,
            videosDirectory,
            imagesDirectory,
            htmlDirectory,
            dataDirectory
        ]
        
        for directory in directories {
            createDirectoryIfNeeded(at: directory)
        }
    }
    
    /// Creates a directory if it doesn't exist
    private func createDirectoryIfNeeded(at url: URL) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                print("Created directory: \(url.path)")
            } catch {
                print("Failed to create directory: \(error)")
            }
        }
    }
    
    // MARK: - File URLs
    
    /// Get the full URL for an image filename
    func imageURL(for filename: String) -> URL {
        imagesDirectory.appendingPathComponent(filename)
    }
    
    /// Get the full URL for a video filename
    func videoURL(for filename: String) -> URL {
        videosDirectory.appendingPathComponent(filename)
    }
    
    /// Get the full URL for an HTML filename
    func htmlURL(for filename: String) -> URL {
        htmlDirectory.appendingPathComponent(filename)
    }
    
    // MARK: - File Operations
    
    /// Check if a file exists
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Check if an image exists
    func imageExists(filename: String) -> Bool {
        fileExists(at: imageURL(for: filename))
    }
    
    /// Check if a video exists
    func videoExists(filename: String) -> Bool {
        fileExists(at: videoURL(for: filename))
    }
    
    /// Copy a file to the images directory
    @discardableResult
    func copyToImages(from sourceURL: URL, filename: String? = nil) -> URL? {
        let destinationFilename = filename ?? sourceURL.lastPathComponent
        let destinationURL = imageURL(for: destinationFilename)
        return copyFile(from: sourceURL, to: destinationURL)
    }
    
    /// Copy a file to the videos directory
    @discardableResult
    func copyToVideos(from sourceURL: URL, filename: String? = nil) -> URL? {
        let destinationFilename = filename ?? sourceURL.lastPathComponent
        let destinationURL = videoURL(for: destinationFilename)
        return copyFile(from: sourceURL, to: destinationURL)
    }
    
    /// Copy a file from source to destination
    private func copyFile(from sourceURL: URL, to destinationURL: URL) -> URL? {
        let fileManager = FileManager.default
        
        // Remove existing file if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            do {
                try fileManager.removeItem(at: destinationURL)
            } catch {
                print("Failed to remove existing file: \(error)")
                return nil
            }
        }
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("Copied file to: \(destinationURL.path)")
            return destinationURL
        } catch {
            print("Failed to copy file: \(error)")
            return nil
        }
    }
    
    /// Delete a file
    func deleteFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("Failed to delete file: \(error)")
            return false
        }
    }
    
    // MARK: - Content Listing
    
    /// List all image files in the images directory
    func listImages() -> [URL] {
        listFiles(in: imagesDirectory, withExtensions: ["jpg", "jpeg", "png", "heic", "gif"])
    }
    
    /// List all video files in the videos directory
    func listVideos() -> [URL] {
        listFiles(in: videosDirectory, withExtensions: ["mp4", "mov", "m4v"])
    }
    
    /// List files in a directory with specific extensions
    private func listFiles(in directory: URL, withExtensions extensions: [String]) -> [URL] {
        let fileManager = FileManager.default
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        
        return files.filter { url in
            extensions.contains(url.pathExtension.lowercased())
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    
    // MARK: - Image Loading
    
    /// Load a UIImage from the images directory
    func loadImage(filename: String) -> UIImage? {
        let url = imageURL(for: filename)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    /// Save a UIImage to the images directory
    @discardableResult
    func saveImage(_ image: UIImage, filename: String, compressionQuality: CGFloat = 0.9) -> URL? {
        let url = imageURL(for: filename)
        
        let data: Data?
        let ext = (filename as NSString).pathExtension.lowercased()
        
        if ext == "png" {
            data = image.pngData()
        } else {
            data = image.jpegData(compressionQuality: compressionQuality)
        }
        
        guard let imageData = data else {
            return nil
        }
        
        do {
            try imageData.write(to: url)
            return url
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    // MARK: - Playlist Switching
    
    /// Switch to a different playlist
    func switchToPlaylist(named name: String) {
        currentPlaylistName = name
        setupDirectoryStructure()
    }
}
