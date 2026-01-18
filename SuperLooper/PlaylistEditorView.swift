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
            }
            .sheet(item: $editingItem) { item in
                ItemEditorView(playlistManager: playlistManager, item: item)
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
            // Type icon
            Image(systemName: item.contentType.iconName)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 36)
            
            // Item info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                
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
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text(item.transition.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Item name", text: $name)
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
                
                Section("Transition") {
                    Picker("Transition", selection: $transition) {
                        ForEach(TransitionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(transition.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
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
                transition = item.transition
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
        
        playlistManager.items[index] = updatedItem
        playlistManager.savePlaylist()
    }
}

// MARK: - Preview

#Preview {
    PlaylistEditorView(playlistManager: PlaylistManager(items: []))
}
