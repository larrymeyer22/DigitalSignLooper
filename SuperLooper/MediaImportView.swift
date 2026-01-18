//
//  MediaImportView.swift
//  Super Looper
//
//  Import photos and videos from the Photos app into the playlist
//

import SwiftUI
import PhotosUI
import AVFoundation

struct MediaImportView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var importedCount = 0
    @State private var errorMessage: String?
    @State private var mediaType: MediaTypeFilter = .all
    
    enum MediaTypeFilter: String, CaseIterable {
        case all = "All"
        case photos = "Photos"
        case videos = "Videos"
        
        var matching: PHPickerFilter {
            switch self {
            case .all: return .any(of: [.images, .videos])
            case .photos: return .images
            case .videos: return .videos
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                // Instructions
                Text("Import Media")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Select photos and videos to add to your playlist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Media type filter
                Picker("Media Type", selection: $mediaType) {
                    ForEach(MediaTypeFilter.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                
                // Photo Picker
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 50,
                    matching: mediaType.matching,
                    photoLibrary: .shared()
                ) {
                    Label("Select Media", systemImage: "plus.square.on.square")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .disabled(isImporting)
                .id(mediaType) // Force picker refresh when filter changes
                
                // Selection count
                if !selectedItems.isEmpty {
                    Text("\(selectedItems.count) item\(selectedItems.count == 1 ? "" : "s") selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Import button
                if !selectedItems.isEmpty {
                    Button(action: importMedia) {
                        if isImporting {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text("Importing... \(importedCount)/\(selectedItems.count)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        } else {
                            Label("Add to Playlist", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(isImporting)
                    .padding(.horizontal, 40)
                }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
                
                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tip: Videos will play to completion", systemImage: "info.circle")
                    Label("Tip: Photos display for the default duration (10s)", systemImage: "info.circle")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            }
            .navigationTitle("Import Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isImporting)
                }
            }
        }
    }
    
    private func importMedia() {
        isImporting = true
        importedCount = 0
        errorMessage = nil
        
        Task {
            var successCount = 0
            
            for (index, item) in selectedItems.enumerated() {
                do {
                    // Check if it's a video or image
                    let supportedTypes = item.supportedContentTypes
                    let isVideo = supportedTypes.contains { $0.conforms(to: .movie) || $0.conforms(to: .video) }
                    
                    if isVideo {
                        // Handle video
                        if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
                            let filename = "video_\(UUID().uuidString.prefix(8)).mp4"
                            
                            // Copy to Videos folder
                            if let destURL = FileSystemManager.shared.copyToVideos(from: movie.url, filename: filename) {
                                // Create playlist item
                                let playlistItem = PlaylistItem.video(
                                    name: "Video \(playlistManager.itemCount + successCount + 1)",
                                    filename: filename
                                )
                                
                                await MainActor.run {
                                    playlistManager.addItem(playlistItem)
                                    successCount += 1
                                    importedCount = index + 1
                                }
                                
                                // Clean up temp file
                                try? FileManager.default.removeItem(at: movie.url)
                            }
                        }
                    } else {
                        // Handle image
                        if let data = try await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            
                            let filename = "photo_\(UUID().uuidString.prefix(8)).jpg"
                            
                            if let _ = FileSystemManager.shared.saveImage(image, filename: filename) {
                                let playlistItem = PlaylistItem.image(
                                    name: "Photo \(playlistManager.itemCount + successCount + 1)",
                                    filename: filename,
                                    duration: 10.0
                                )
                                
                                await MainActor.run {
                                    playlistManager.addItem(playlistItem)
                                    successCount += 1
                                    importedCount = index + 1
                                }
                            }
                        }
                    }
                } catch {
                    print("Failed to import media: \(error)")
                }
            }
            
            await MainActor.run {
                isImporting = false
                
                if successCount > 0 {
                    playlistManager.savePlaylist()
                    dismiss()
                } else {
                    errorMessage = "Failed to import media. Please try again."
                }
            }
        }
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copy to temp location
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return VideoTransferable(url: tempURL)
        }
    }
}

// MARK: - Preview

#Preview {
    MediaImportView(playlistManager: PlaylistManager(items: []))
}
