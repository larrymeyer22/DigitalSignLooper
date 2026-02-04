//
//  StartupView.swift
//  Super Looper
//
//  Playlist selection screen shown at app launch
//

import SwiftUI
import UniformTypeIdentifiers

struct StartupView: View {
    var libraryManager = PlaylistLibraryManager.shared
    @Binding var selectedPlaylist: PlaylistInfo?
    
    @State private var showingNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var playlistToRename: PlaylistInfo?
    @State private var renameText = ""
    @State private var playlistToDelete: PlaylistInfo?
    @State private var showDeleteConfirm = false
    @State private var showImportPicker = false
    @State private var importError: String?
    
    // Edit mode for reordering and deleting
    @State private var isEditing = false
    @State private var orderedPlaylists: [PlaylistInfo] = []
    @State private var draggedPlaylist: PlaylistInfo?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - dark gray
                Color(white: 0.12)
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
                // Remove from ordered list first
                orderedPlaylists.removeAll { $0.id == playlist.id }
                savePlaylistOrder()
                // Then delete from storage
                libraryManager.deletePlaylist(playlist)
                playlistToDelete = nil
            }
        } message: { playlist in
            Text("Are you sure you want to delete \"\(playlist.name)\"? This cannot be undone.")
        }
        .alert("Import Error", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "Unknown error")
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.folder, .json, .zip, .archive],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Import Handler
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task { @MainActor in
                do {
                    let imported: Playlist
                    
                    if url.pathExtension.lowercased() == "zip" {
                        // Handle zip file automatically
                        imported = try await PlaylistStorageManager.shared.importPlaylistFromZip(at: url)
                    } else if url.pathExtension.lowercased() == "json" {
                        // User selected playlist.json directly
                        imported = try await PlaylistStorageManager.shared.importPlaylistFromJSON(at: url)
                    } else {
                        // User selected folder
                        imported = try await PlaylistStorageManager.shared.importPlaylistFolder(from: url)
                    }
                    
                    // Select the newly imported playlist
                    selectedPlaylist = imported
                } catch {
                    importError = error.localizedDescription
                }
            }
            
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Edit button row
            HStack {
                Spacer()
                if !libraryManager.playlists.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing.toggle()
                        }
                    }) {
                        Text(isEditing ? "Done" : "Edit")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(white: 0.25))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 10)
            
            Text("DigitalSignLooper")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(isEditing ? "Drag to reorder, tap ✕ to delete" : "Select a playlist to get started")
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
            
            HStack(spacing: 16) {
                Button(action: { showingNewPlaylistAlert = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(red: 0.25, green: 0.41, blue: 0.88))
                        Text("Create Playlist")
                            .foregroundColor(.white)
                    }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color(white: 0.25))
                    .cornerRadius(16)
                }
                
                Button(action: { showImportPicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(Color(red: 0.25, green: 0.41, blue: 0.88))
                        Text("Import Playlist")
                            .foregroundColor(.white)
                    }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color(white: 0.25))
                    .cornerRadius(16)
                }
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
                    GridItem(.adaptive(minimum: 280), spacing: 20)
                ], spacing: 20) {
                    // New playlist card (hidden in edit mode)
                    if !isEditing {
                        NewPlaylistCard {
                            showingNewPlaylistAlert = true
                        }
                        
                        // Import playlist card
                        ImportPlaylistCard {
                            showImportPicker = true
                        }
                    }
                    
                    // Existing playlists
                    ForEach(orderedPlaylists, id: \.id) { playlist in
                        PlaylistCardWithEdit(
                            playlist: playlist,
                            isEditing: isEditing,
                            onTap: {
                                if !isEditing {
                                    selectPlaylist(playlist)
                                }
                            },
                            onDelete: {
                                playlistToDelete = playlist
                                showDeleteConfirm = true
                            },
                            onLongPress: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditing = true
                                }
                            }
                        )
                        .onDrag {
                            draggedPlaylist = playlist
                            return NSItemProvider(object: playlist.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: PlaylistDropDelegate(
                            item: playlist,
                            items: $orderedPlaylists,
                            draggedItem: $draggedPlaylist,
                            onReorder: savePlaylistOrder
                        ))
                        .contextMenu {
                            if !isEditing {
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
                                    Task {
                                        _ = try? await libraryManager.duplicatePlaylist(playlist)
                                        refreshOrderedPlaylists()
                                    }
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
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            refreshOrderedPlaylists()
        }
        .onChange(of: libraryManager.playlists) { _, _ in
            refreshOrderedPlaylists()
        }
    }
    
    // MARK: - Playlist Order Management
    
    private func refreshOrderedPlaylists() {
        // Load saved order or use default (by modified date)
        let savedOrder = UserDefaults.standard.stringArray(forKey: "PlaylistOrder") ?? []
        
        let playlists = libraryManager.playlists
        
        if savedOrder.isEmpty {
            // Default: sort by modified date
            orderedPlaylists = playlists.sorted { $0.modifiedAt > $1.modifiedAt }
        } else {
            // Use saved order, with new playlists at the end
            var ordered: [PlaylistInfo] = []
            for idString in savedOrder {
                if let playlist = playlists.first(where: { $0.id.uuidString == idString }) {
                    ordered.append(playlist)
                }
            }
            // Add any playlists not in saved order
            for playlist in playlists {
                if !ordered.contains(where: { $0.id == playlist.id }) {
                    ordered.append(playlist)
                }
            }
            orderedPlaylists = ordered
        }
    }
    
    private func savePlaylistOrder() {
        let order = orderedPlaylists.map { $0.id.uuidString }
        UserDefaults.standard.set(order, forKey: "PlaylistOrder")
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
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(playlist.itemCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    +
                    Text(" items")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Text(playlist.name.isEmpty ? "(Unnamed)" : playlist.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text("Modified \(playlist.modifiedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .background(Color(white: 0.18))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Playlist Card With Edit Mode

struct PlaylistCardWithEdit: View {
    let playlist: PlaylistInfo
    let isEditing: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    @State private var wiggleRotation: Double = 0
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main card content
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(playlist.itemCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    +
                    Text(" items")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Text(playlist.name.isEmpty ? "(Unnamed)" : playlist.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text("Modified \(playlist.modifiedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .background(Color(white: 0.18))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isEditing ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            // Wiggle animation in edit mode
            .rotationEffect(.degrees(wiggleRotation))
            .onChange(of: isEditing) { _, editing in
                if editing {
                    // Start wiggle
                    withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                        wiggleRotation = 1.0
                    }
                } else {
                    // Stop wiggle
                    withAnimation(.easeInOut(duration: 0.1)) {
                        wiggleRotation = 0
                    }
                }
            }
            .onAppear {
                // Handle case where view appears already in edit mode
                if isEditing {
                    withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                        wiggleRotation = 1.0
                    }
                }
            }
            
            // Delete badge (only in edit mode)
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.red))
                }
                .offset(x: -8, y: -8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            isPressed = pressing
        }) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onLongPress()
        }
    }
}

// MARK: - Playlist Drop Delegate

struct PlaylistDropDelegate: DropDelegate {
    let item: PlaylistInfo
    @Binding var items: [PlaylistInfo]
    @Binding var draggedItem: PlaylistInfo?
    let onReorder: () -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        onReorder()
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - New Playlist Card

struct NewPlaylistCard: View {
    let onTap: () -> Void
    
    private let royalBlue = Color(red: 0.25, green: 0.41, blue: 0.88)
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(royalBlue)
                
                Text("New Playlist")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(Color(white: 0.18))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(royalBlue.opacity(0.5), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Import Playlist Card

struct ImportPlaylistCard: View {
    let onTap: () -> Void
    
    private let royalBlue = Color(red: 0.25, green: 0.41, blue: 0.88)
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 40))
                    .foregroundColor(royalBlue)
                
                Text("Import Playlist")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(Color(white: 0.18))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(royalBlue.opacity(0.5), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    StartupView(selectedPlaylist: .constant(nil))
}
