//
//  AirDropPlaylistPicker.swift
//  DigitalSignLooper
//
//  Playlist picker shown when AirDrop files are received without an active playlist
//

import SwiftUI

struct AirDropPlaylistPicker: View {
    @ObservedObject var airDropHandler: AirDropHandler
    @ObservedObject var libraryManager = PlaylistLibraryManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlaylist: Playlist?
    @State private var isImporting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("AirDrop Received")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Select a playlist to add \(airDropHandler.pendingURLs.count) file\(airDropHandler.pendingURLs.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Playlist List
                if libraryManager.playlists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Playlists")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Create a playlist first to import files")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                } else {
                    List(libraryManager.playlists) { playlist in
                        Button {
                            selectedPlaylist = playlist
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(playlist.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(playlist.itemCount) item\(playlist.itemCount == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedPlaylist?.id == playlist.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Choose Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        airDropHandler.pendingURLs = []
                        dismiss()
                    }
                    .disabled(isImporting)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importFiles()
                    }
                    .disabled(selectedPlaylist == nil || isImporting)
                }
            }
            .overlay {
                if isImporting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Importing files...")
                                .font(.headline)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThickMaterial)
                        )
                    }
                }
            }
        }
    }
    
    private func importFiles() {
        guard let playlist = selectedPlaylist else { return }
        
        isImporting = true
        
        Task { @MainActor in
            // Find the full playlist from the library
            if let fullPlaylist = libraryManager.playlists.first(where: { $0.id == playlist.id }) {
                // Create a temporary PlaylistManager for this playlist
                let tempManager = PlaylistManager(items: fullPlaylist.items)
                
                // Set the current playlist so it knows where to save media
                tempManager.currentPlaylist = fullPlaylist
                
                // Import the files
                await airDropHandler.importFiles(airDropHandler.pendingURLs, to: tempManager)
                
                // Save the updated playlist back
                let updatedPlaylist = Playlist(
                    id: fullPlaylist.id,
                    name: fullPlaylist.name,
                    description: fullPlaylist.description,
                    items: tempManager.items,
                    createdAt: fullPlaylist.createdAt,
                    modifiedAt: Date(),
                    settings: fullPlaylist.settings,
                    crawlData: fullPlaylist.crawlData
                )
                
                do {
                    try await libraryManager.save(updatedPlaylist)
                } catch {
                    print("⚠️ Failed to save playlist: \(error)")
                }
            }
            
            isImporting = false
            dismiss()
        }
    }
}
