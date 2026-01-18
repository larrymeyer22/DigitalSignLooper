//
//  StartupView.swift
//  Super Looper
//
//  Playlist selection screen shown at app launch
//

import SwiftUI

struct StartupView: View {
    var libraryManager = PlaylistLibraryManager.shared
    @Binding var selectedPlaylist: PlaylistInfo?
    
    @State private var showingNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var playlistToRename: PlaylistInfo?
    @State private var renameText = ""
    @State private var playlistToDelete: PlaylistInfo?
    @State private var showDeleteConfirm = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.top, 60)
                        .padding(.bottom, 40)
                    
                    // Content
                    if libraryManager.playlists.isEmpty {
                        emptyStateView
                    } else {
                        playlistGridView
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .alert("New Playlist", isPresented: $showingNewPlaylistAlert) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) {
                newPlaylistName = ""
            }
            Button("Create") {
                createNewPlaylist()
            }
        } message: {
            Text("Enter a name for your new playlist")
        }
        .alert("Rename Playlist", isPresented: .init(
            get: { playlistToRename != nil },
            set: { if !$0 { playlistToRename = nil } }
        )) {
            TextField("Playlist name", text: $renameText)
            Button("Cancel", role: .cancel) {
                playlistToRename = nil
                renameText = ""
            }
            Button("Rename") {
                if let playlist = playlistToRename {
                    libraryManager.renamePlaylist(playlist, to: renameText)
                }
                playlistToRename = nil
                renameText = ""
            }
        } message: {
            Text("Enter a new name for this playlist")
        }
        .alert("Delete Playlist?", isPresented: $showDeleteConfirm, presenting: playlistToDelete) { playlist in
            Button("Cancel", role: .cancel) {
                playlistToDelete = nil
            }
            Button("Delete", role: .destructive) {
                libraryManager.deletePlaylist(playlist)
                playlistToDelete = nil
            }
        } message: { playlist in
            Text("Are you sure you want to delete \"\(playlist.name)\"? This cannot be undone.")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 10)
            
            Text("Super Looper")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Select a playlist to get started")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No Playlists Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Create your first playlist to start displaying content")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingNewPlaylistAlert = true }) {
                Label("Create Playlist", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .foregroundColor(.blue)
                    .cornerRadius(16)
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    // MARK: - Playlist Grid
    
    private var playlistGridView: some View {
        VStack(spacing: 20) {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 350), spacing: 20)
                ], spacing: 20) {
                    // New playlist card
                    NewPlaylistCard {
                        showingNewPlaylistAlert = true
                    }
                    
                    // Existing playlists
                    ForEach(libraryManager.playlists.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { playlist in
                        PlaylistCard(playlist: playlist) {
                            selectPlaylist(playlist)
                        }
                        .contextMenu {
                            Button {
                                selectPlaylist(playlist)
                            } label: {
                                Label("Open", systemImage: "play.fill")
                            }
                            
                            Button {
                                renameText = playlist.name
                                playlistToRename = playlist
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            
                            Button {
                                libraryManager.duplicatePlaylist(playlist)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                playlistToDelete = playlist
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Actions
    
    private func createNewPlaylist() {
        guard !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        let playlist = libraryManager.createPlaylist(name: newPlaylistName)
        newPlaylistName = ""
        selectPlaylist(playlist)
    }
    
    private func selectPlaylist(_ playlist: PlaylistInfo) {
        libraryManager.selectPlaylist(playlist)
        selectedPlaylist = playlist
    }
}

// MARK: - Playlist Card

struct PlaylistCard: View {
    let playlist: PlaylistInfo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("\(playlist.itemCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    +
                    Text(" items")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(playlist.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text("Modified \(playlist.modifiedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - New Playlist Card

struct NewPlaylistCard: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("New Playlist")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(Color(.systemBackground).opacity(0.8))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    StartupView(selectedPlaylist: .constant(nil))
}
