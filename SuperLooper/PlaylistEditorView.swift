//
//  PlaylistEditorView.swift
//  Super Looper
//
//  Edit playlist: reorder, delete, and modify items
//

import SwiftUI

struct PlaylistEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var editingItem: PlaylistItem?
    @State private var showingMediaImport = false
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: PlaylistItem?
    
    var body: some View {
        NavigationStack {
            Group {
                if playlistManager.items.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        playlistManager.savePlaylist()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingMediaImport = true }) {
                            Label("Import Media", systemImage: "photo.on.rectangle.angled")
                        }
                        
                        Button(action: addSampleContent) {
                            Label("Add Sample Content", systemImage: "star.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingMediaImport) {
                MediaImportView(playlistManager: playlistManager)
                    .preferredColorScheme(.dark)
            }
            .sheet(item: $editingItem) { item in
                ItemEditorView(playlistManager: playlistManager, item: item)
                    .preferredColorScheme(.dark)
            }
            .alert("Delete Item?", isPresented: $showingDeleteAlert, presenting: itemToDelete) { item in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteItem(item)
                }
            } message: { item in
                Text("Are you sure you want to delete \"\(item.name)\"?")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Items")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("Add content to your playlist")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
            
            Button(action: { showingMediaImport = true }) {
                Label("Import Media", systemImage: "photo.on.rectangle.angled")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
    }
    
    private var listView: some View {
        List {
            ForEach(playlistManager.items) { item in
                PlaylistEditorRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingItem = item
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleHidden(item)
                        } label: {
                            Label(
                                item.isHidden ? "Show" : "Hide",
                                systemImage: item.isHidden ? "eye" : "eye.slash"
                            )
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onMove(perform: moveItems)
            .onDelete(perform: deleteItems)
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        playlistManager.moveItem(from: source, to: destination)
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets.sorted().reversed() {
            playlistManager.removeItem(at: index)
        }
    }
    
    private func deleteItem(_ item: PlaylistItem) {
        if let index = playlistManager.items.firstIndex(where: { $0.id == item.id }) {
            playlistManager.removeItem(at: index)
        }
    }
    
    private func toggleHidden(_ item: PlaylistItem) {
        if let index = playlistManager.items.firstIndex(where: { $0.id == item.id }) {
            playlistManager.toggleItemHidden(at: index)
        }
    }
    
    private func addSampleContent() {
        // Add a sample HTML item for testing
        let sampleHTML = """
        <div style="text-align: center; padding: 40px;">
            <h1 style="font-size: 64px; color: #007AFF; margin-bottom: 20px;">Welcome!</h1>
            <p style="font-size: 32px; color: #888;">Super Looper Demo</p>
        </div>
        """
        
        let item = PlaylistItem.html(
            name: "Welcome Slide",
            content: sampleHTML,
            duration: 8.0
        )
        
        playlistManager.addItem(item)
        playlistManager.savePlaylist()
    }
}

// MARK: - Playlist Editor Row

struct PlaylistEditorRow: View {
    let item: PlaylistItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Hidden indicator
            if item.isHidden {
                Image(systemName: "eye.slash.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .frame(width: 20)
            } else {
                Color.clear.frame(width: 20)
            }
            
            // Type icon
            Image(systemName: item.contentType.iconName)
                .font(.title2)
                .foregroundColor(item.isHidden ? .gray : .blue)
                .frame(width: 36)
            
            // Item info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(item.isHidden ? .secondary : .primary)
                    
                    if item.isHidden {
                        Text("(Hidden)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(item.contentType.typeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !item.contentType.hasFixedDuration {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("\(Int(item.duration))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Transition badge (like Keynote transition indicator)
            HStack(spacing: 4) {
                Image(systemName: item.transition.normalized.iconName)
                    .font(.caption)
                Text(item.transition.normalized.displayName)
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
            )
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .opacity(item.isHidden ? 0.5 : 1.0)
    }
}

// MARK: - Item Editor View

struct ItemEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    let item: PlaylistItem
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var duration: Double = 10
    @State private var transition: TransitionType = .dissolve
    @State private var transitionDuration: Double = 0.5
    @State private var isHidden: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Item name", text: $name)
                }
                
                Section {
                    Toggle(isOn: $isHidden) {
                        Label(
                            isHidden ? "Hidden from playlist" : "Visible in playlist",
                            systemImage: isHidden ? "eye.slash" : "eye"
                        )
                    }
                    .tint(.orange)
                } header: {
                    Text("Visibility")
                } footer: {
                    Text("Hidden items will be skipped during playback, like hiding slides in PowerPoint")
                }
                
                Section("Display Duration") {
                    if item.contentType.hasFixedDuration {
                        Text("Video plays to completion")
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("\(Int(duration)) seconds")
                                Spacer()
                            }
                            
                            Slider(value: $duration, in: 3...60, step: 1)
                        }
                    }
                }
                
                TransitionPickerSection(transition: $transition, transitionDuration: $transitionDuration)
                
                Section("Content Type") {
                    HStack {
                        Image(systemName: item.contentType.iconName)
                            .foregroundColor(.blue)
                        Text(item.contentType.typeName)
                        Spacer()
                        
                        // Show filename or URL
                        switch item.contentType {
                        case .image(let filename):
                            Text(filename)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .video(let filename):
                            Text(filename)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .web(let url):
                            Text(url.host ?? url.absoluteString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .html:
                            Text("Custom HTML")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .liveWeb(let url, _):
                            Text(url.host ?? url.absoluteString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .customHTML(let filename):
                            Text(filename)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .titleSlide(let data):
                            Text(data.headline)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        case .featuredPerson(let data):
                            Text(data.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .schedule(let data):
                            Text("\(data.events.count) events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .leaderboard(let data):
                            Text("\(data.entries.count) entries")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .countdown(let data):
                            Text(data.mode == .targetTime ? "Target Time" : "Duration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .weather(let data):
                            Text(data.locationName.isEmpty ? "Weather" : data.locationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = item.name
                duration = item.duration
                transition = item.transition.normalized
                transitionDuration = item.transitionDuration
                isHidden = item.isHidden
            }
        }
    }
    
    private func saveChanges() {
        guard let index = playlistManager.items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        
        var updatedItem = item
        updatedItem.name = name
        updatedItem.duration = duration
        updatedItem.transition = transition
        updatedItem.transitionDuration = transitionDuration
        updatedItem.isHidden = isHidden
        
        playlistManager.items[index] = updatedItem
        playlistManager.savePlaylist()
    }
}

// MARK: - Preview

#Preview {
    PlaylistEditorView(playlistManager: PlaylistManager(items: []))
}
