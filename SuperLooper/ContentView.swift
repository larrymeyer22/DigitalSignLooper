//
//  ContentView.swift
//  Super Looper
//
//  Main view for playlist playback with transitions
//

import SwiftUI
import PhotosUI
import AVFoundation

struct ContentView: View {
    let playlist: PlaylistInfo
    let onExit: () -> Void
    
    // Use SHARED playlist manager - same instance as external display
    @ObservedObject private var playlistManager = SharedPlaylistManager.shared.manager
    @StateObject private var externalDisplayManager = ExternalDisplayManager.shared
    
    @State private var showSidebar: Bool = true
    @State private var showSettings = false
    
    // Direct photo picker - streamlined import
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    
    // Playlist editing state
    @State private var isEditingPlaylist = false
    @State private var selectedItemIndex: Int? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Main content area
                HStack(spacing: 0) {
                    // Sidebar + Inspector
                    if showSidebar {
                        // Playlist sidebar (fixed position)
                        PlaylistSidebarView(
                            playlistManager: playlistManager, 
                            playlistName: playlist.name,
                            selectedPhotoItems: $selectedPhotoItems,
                            isEditing: $isEditingPlaylist,
                            selectedItemIndex: $selectedItemIndex
                        )
                        .frame(width: 280)
                        
                        // Inspector panel (appears to the right when item selected)
                        if isEditingPlaylist && selectedItemIndex != nil {
                            ItemInspectorPanel(
                                playlistManager: playlistManager,
                                selectedItemIndex: $selectedItemIndex
                            )
                            .frame(width: 260)
                        }
                    }
                    
                    // Content display area
                    ZStack {
                        // Always show content on iPad
                        ContentDisplayView(playlistManager: playlistManager)
                        
                        // Top toolbar
                        VStack {
                            SimpleToolbarView(
                                showSettings: $showSettings,
                                isExternalConnected: externalDisplayManager.isConnected
                            )
                            .padding()
                            
                            Spacer()
                        }
                        
                        // Bottom-right control panel
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ControlPanelView(playlistManager: playlistManager, showSidebar: $showSidebar)
                                    .padding()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isEditingPlaylist)
        .animation(.easeInOut(duration: 0.25), value: selectedItemIndex)
        .animation(.easeInOut(duration: 0.3), value: showSidebar)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            // Load saved playlist on launch
            playlistManager.loadPlaylistFromDisk()
        }
        .onChange(of: playlistManager.itemCount) { _, newCount in
            // Sync item count with library
            PlaylistLibraryManager.shared.updateItemCount(for: playlist, count: newCount)
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            // Auto-import when photos are selected
            if !newItems.isEmpty {
                importSelectedMedia(newItems)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(playlistManager: playlistManager, playlistName: playlist.name, onExit: onExit)
        }
    }
    
    // MARK: - Streamlined Import
    
    private func importSelectedMedia(_ items: [PhotosPickerItem]) {
        guard !isImporting else { return }
        isImporting = true
        
        Task {
            var successCount = 0
            
            for item in items {
                do {
                    // Try video first
                    if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
                        // Get video duration from source URL first
                        let sourceAsset = AVAsset(url: movie.url)
                        var videoDuration: TimeInterval = 0
                        do {
                            let duration = try await sourceAsset.load(.duration)
                            let seconds = CMTimeGetSeconds(duration)
                            if seconds.isFinite && seconds > 0 {
                                videoDuration = seconds
                            }
                            print("✅ Video duration: \(videoDuration)s")
                        } catch {
                            print("⚠️ Failed to get video duration: \(error)")
                        }
                        
                        let filename = "video_\(UUID().uuidString.prefix(8)).mp4"
                        if let destURL = FileSystemManager.shared.copyToVideos(from: movie.url, filename: filename) {
                            let playlistItem = PlaylistItem(
                                name: filename,
                                contentType: .video(filename: destURL.lastPathComponent),
                                duration: videoDuration
                            )
                            await MainActor.run {
                                playlistManager.addItem(playlistItem)
                            }
                            successCount += 1
                        }
                    }
                    // Then try image
                    else if let data = try await item.loadTransferable(type: Data.self),
                            let image = UIImage(data: data) {
                        let filename = "image_\(UUID().uuidString.prefix(8)).jpg"
                        if let savedURL = FileSystemManager.shared.saveImage(image, filename: filename) {
                            let playlistItem = PlaylistItem(
                                name: filename,
                                contentType: .image(filename: savedURL.lastPathComponent)
                            )
                            await MainActor.run {
                                playlistManager.addItem(playlistItem)
                            }
                            successCount += 1
                        }
                    }
                } catch {
                    print("Failed to import: \(error)")
                }
            }
            
            await MainActor.run {
                if successCount > 0 {
                    playlistManager.savePlaylist()
                }
                selectedPhotoItems = []
                isImporting = false
            }
        }
    }
}

// MARK: - Simple Toolbar View

struct SimpleToolbarView: View {
    @Binding var showSettings: Bool
    var isExternalConnected: Bool = false
    
    var body: some View {
        HStack {
            // External display indicator (left side)
            if isExternalConnected {
                HStack(spacing: 6) {
                    Image(systemName: "tv.fill")
                        .font(.subheadline)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("TV Connected")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.3))
                )
            }
            
            Spacer()
            
            // Settings button only
            Button(action: { showSettings = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                    Text("Settings")
                        .font(.caption2)
                }
                .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
        }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var playlistManager: PlaylistManager
    let playlistName: String
    let onExit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var transitionDuration: Double = 0.5
    @State private var showClearConfirm = false
    @State private var showExitConfirm = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Current Playlist") {
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.blue)
                        Text(playlistName)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Items")
                        Spacer()
                        Text("\(playlistManager.itemCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Playback") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Transition Duration")
                            Spacer()
                            Text("\(transitionDuration, specifier: "%.1f")s")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $transitionDuration, in: 0.2...2.0, step: 0.1)
                    }
                }
                
                Section {
                    Button {
                        showExitConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.stack")
                            Text("Switch Playlist")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Clear All Items")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        playlistManager.transitionDuration = transitionDuration
                        dismiss()
                    }
                }
            }
            .onAppear {
                transitionDuration = playlistManager.transitionDuration
            }
            .alert("Clear Playlist?", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    playlistManager.clearPlaylist()
                    dismiss()
                }
            } message: {
                Text("This will remove all items from the playlist. This cannot be undone.")
            }
            .alert("Switch Playlist?", isPresented: $showExitConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Switch") {
                    dismiss()
                    // Small delay to let sheet dismiss first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onExit()
                    }
                }
            } message: {
                Text("Return to the playlist selection screen?")
            }
        }
    }
}

// MARK: - Content Display View with Seamless Crossfade

struct ContentDisplayView: View {
    @ObservedObject var playlistManager: PlaylistManager
    
    var body: some View {
        ZStack {
            Color.black
            
            // Previous item (fading OUT during transition)
            if let previous = playlistManager.previousItem {
                contentView(for: previous, isOutgoing: true)
                    .id("previous-\(previous.id)")
                    .opacity(playlistManager.isTransitioning ? 0 : 1)
                    .animation(.linear(duration: playlistManager.transitionDuration), value: playlistManager.isTransitioning)
            }
            
            // Current item (fading IN during transition)
            if let item = playlistManager.currentItem {
                contentView(for: item, isOutgoing: false)
                    .id("current-\(item.id)")
                    .opacity(playlistManager.isTransitioning && playlistManager.previousItem != nil ? 1 : 1)
                    .animation(.linear(duration: playlistManager.transitionDuration), value: item.id)
            }
            
            // Empty state
            if playlistManager.currentItem == nil && playlistManager.previousItem == nil {
                emptyStateView
            }
        }
    }
    
    @ViewBuilder
    private func contentView(for item: PlaylistItem, isOutgoing: Bool) -> some View {
        switch item.contentType {
        case .image(let filename):
            ImageContentView(filename: filename, preloadedImage: playlistManager.preloadedImageFilename == filename ? playlistManager.preloadedImage : nil)
            
        case .video(let filename):
            // Use outgoing player for previous item, shared player for current
            if isOutgoing {
                OutgoingVideoView(player: playlistManager.outgoingVideoPlayer)
            } else {
                VideoContentView(filename: filename, playlistManager: playlistManager)
            }
            
        case .html(let content):
            HTMLContentView(htmlContent: content)
            
        case .web(let url):
            WebContentView(url: url)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Content")
                .font(.title)
                .foregroundColor(.gray)
            
            Text("Add items to your playlist to get started")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
        }
    }
}

// MARK: - Outgoing Video View (for crossfade transitions)

import AVKit

struct OutgoingVideoView: View {
    let player: AVPlayer?
    
    var body: some View {
        ZStack {
            Color.black
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
            }
        }
    }
}

// MARK: - Playlist Sidebar

struct PlaylistSidebarView: View {
    @ObservedObject var playlistManager: PlaylistManager
    var playlistName: String = "Playlist"
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var isEditing: Bool
    @Binding var selectedItemIndex: Int?
    
    private var totalDuration: TimeInterval {
        playlistManager.items.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlistName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(playlistManager.itemCount) items, \(formatTotalDuration(totalDuration))")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .padding(.vertical, 4)
                }
                
                Spacer()
                
                // Edit button
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing.toggle()
                        if !isEditing {
                            selectedItemIndex = nil
                        }
                    }
                }) {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Add button (only in edit mode)
            if isEditing {
                VStack(spacing: 0) {
                    // Photos & Videos picker
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 50,
                        matching: .any(of: [.images, .videos]),
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title3)
                                .foregroundColor(.blue)
                            
                            Text("Add Photos & Videos")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                    }
                    
                    // Content Templates (placeholder for later)
                    Button(action: {
                        // TODO: Content templates
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.title3)
                                .foregroundColor(.gray)
                            
                            Text("Content Templates")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("Coming Soon")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .disabled(true)
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
            }
            
            // Item list
            if isEditing {
                // Edit mode: List with drag to reorder
                List {
                    ForEach(Array(playlistManager.items.enumerated()), id: \.element.id) { index, item in
                        PlaylistItemRow(
                            item: item,
                            index: index,
                            isActive: selectedItemIndex == index,
                            progress: 0,
                            isEditing: isEditing,
                            onDelete: {
                                withAnimation {
                                    if selectedItemIndex == index {
                                        selectedItemIndex = nil
                                    }
                                    playlistManager.removeItem(at: index)
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedItemIndex = index
                            }
                        }
                    }
                    .onMove { from, to in
                        playlistManager.moveItem(from: from, to: to)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                // Normal mode: ScrollView for performance
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(playlistManager.items.enumerated()), id: \.element.id) { index, item in
                                PlaylistItemRow(
                                    item: item,
                                    index: index,
                                    isActive: index == playlistManager.currentIndex,
                                    progress: index == playlistManager.currentIndex ? playlistManager.currentProgress : 0,
                                    isEditing: isEditing,
                                    onDelete: nil
                                )
                                .id(item.id)
                                .onTapGesture {
                                    playlistManager.jumpTo(index: index)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: playlistManager.currentIndex) { _, newIndex in
                        // Auto-scroll to current item
                        if let currentItem = playlistManager.currentItem {
                            withAnimation {
                                proxy.scrollTo(currentItem.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.black.opacity(0.85))
    }
    
    private func formatTotalDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Item Inspector Panel (Inline)

struct ItemInspectorPanel: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Binding var selectedItemIndex: Int?
    
    @State private var itemName: String = ""
    @State private var itemDuration: Double = 10
    @State private var isLoadingDuration: Bool = false
    
    private var item: PlaylistItem? {
        guard let index = selectedItemIndex, index < playlistManager.items.count else { return nil }
        return playlistManager.items[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Inspector")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { 
                    withAnimation {
                        selectedItemIndex = nil 
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            if let item = item, let index = selectedItemIndex {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Item preview
                        HStack(spacing: 12) {
                            Image(systemName: item.contentType.iconName)
                                .font(.title)
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.contentType.typeName)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(itemName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                            }
                        }
                        
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("Name", text: $itemName)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .onChange(of: itemName) { _, newValue in
                                    playlistManager.updateItemName(at: index, name: newValue)
                                }
                        }
                        
                        // Duration (only for non-video items)
                        if !item.contentType.hasFixedDuration {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Duration")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                    
                                    Text(formatDuration(itemDuration))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Slider(value: $itemDuration, in: 1...60, step: 1)
                                    .tint(.blue)
                                    .onChange(of: itemDuration) { _, newValue in
                                        playlistManager.updateItemDuration(at: index, duration: newValue)
                                    }
                                
                                // Quick buttons
                                HStack(spacing: 8) {
                                    ForEach([5, 10, 15, 30], id: \.self) { seconds in
                                        Button(action: { 
                                            itemDuration = Double(seconds)
                                            playlistManager.updateItemDuration(at: index, duration: Double(seconds))
                                        }) {
                                            Text(formatDuration(Double(seconds)))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(itemDuration == Double(seconds) ? Color.blue : Color.white.opacity(0.1))
                                                .foregroundColor(itemDuration == Double(seconds) ? .white : .gray)
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        } else {
                            // Video duration info
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Duration")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                    
                                    if isLoadingDuration {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Text(formatDuration(itemDuration))
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "film")
                                        .foregroundColor(.gray)
                                    Text("Video plays to completion")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                // No item selected
                VStack {
                    Spacer()
                    Text("Select an item to edit")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .background(Color(white: 0.12))
        .onChange(of: selectedItemIndex) { _, _ in
            loadItemData()
        }
        .onAppear {
            loadItemData()
        }
    }
    
    private func loadItemData() {
        guard let item = item, let index = selectedItemIndex else { return }
        itemName = item.name
        itemDuration = item.duration
        
        // For videos with 0 duration, try to load it from the file
        if item.contentType.hasFixedDuration && item.duration == 0 {
            loadVideoDuration(for: item, at: index)
        }
    }
    
    private func loadVideoDuration(for item: PlaylistItem, at index: Int) {
        guard case .video(let filename) = item.contentType else { return }
        
        isLoadingDuration = true
        let url = FileSystemManager.shared.videoURL(for: filename)
        
        Task {
            let asset = AVAsset(url: url)
            do {
                let duration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)
                if seconds.isFinite && seconds > 0 {
                    await MainActor.run {
                        itemDuration = seconds
                        playlistManager.updateItemDuration(at: index, duration: seconds)
                        isLoadingDuration = false
                    }
                } else {
                    await MainActor.run {
                        isLoadingDuration = false
                    }
                }
            } catch {
                print("Failed to load video duration: \(error)")
                await MainActor.run {
                    isLoadingDuration = false
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct PlaylistItemRow: View {
    let item: PlaylistItem
    let index: Int
    let isActive: Bool
    let progress: Double
    var isEditing: Bool = false
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Delete button (edit mode)
            if isEditing {
                Button(action: { onDelete?() }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            // Index number
            if !isEditing {
                Text("\(index + 1)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? .blue : .gray)
                    .frame(width: 24)
            }
            
            // Type icon
            Image(systemName: item.contentType.iconName)
                .font(.body)
                .foregroundColor(isActive ? .blue : .gray)
                .frame(width: 24)
            
            // Item info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(isActive ? .semibold : .regular)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(item.contentType.typeName)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if item.duration > 0 {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(formatDuration(item.duration))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Playing indicator (not in edit mode)
            if isActive && !isEditing {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .symbolEffect(.pulse, isActive: progress > 0)
            }
            
            // Drag handle (edit mode)
            if isEditing {
                Image(systemName: "line.3.horizontal")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(
            ZStack(alignment: .leading) {
                // Edit mode background - solid dark gray for drag visibility
                if isEditing {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.2))
                }
                // Active item background (not in edit mode)
                else if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.15))
                    
                    // Progress bar
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.25))
                            .frame(width: geo.size.width * progress)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                }
            }
        )
        .cornerRadius(8)
        .padding(.horizontal, 8)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Control Panel

struct ControlPanelView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Binding var showSidebar: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Row 1: Sidebar toggle + Progress bar
            HStack(spacing: 20) {
                Button(action: { showSidebar.toggle() }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .opacity(showSidebar ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                
                // Progress bar with time
                HStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: geo.size.width * playlistManager.currentProgress)
                                .animation(.linear(duration: 0.1), value: playlistManager.currentProgress)
                        }
                    }
                    .frame(height: 8)
                    
                    if playlistManager.timeRemaining > 0 {
                        Text(formatTime(playlistManager.timeRemaining))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 50)
                    }
                }
            }
            
            // Row 2: Playback controls
            HStack(spacing: 56) {
                Button(action: { playlistManager.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: { playlistManager.togglePlayback() }) {
                    Image(systemName: playlistManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: { playlistManager.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            
            // Row 3: Media name + position
            if let item = playlistManager.currentItem {
                HStack {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(playlistManager.currentIndex + 1) of \(playlistManager.itemCount)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(width: 330)
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview(traits: .landscapeLeft) {
    ContentView(playlist: PlaylistInfo.sample, onExit: {})
}
