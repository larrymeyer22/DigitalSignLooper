//
//  CustomHTMLEditorView.swift
//  Super Looper
//
//  Form for importing and managing Custom HTML content
//

import SwiftUI
import UniformTypeIdentifiers

struct CustomHTMLEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    // Edit mode
    var editingIndex: Int?
    var existingFilename: String?
    
    // Form state
    @State private var filename: String = ""
    @State private var htmlContent: String = ""
    @State private var duration: Double = 15
    @State private var itemName: String = ""
    @State private var transition: TransitionType = .dissolve
    @State private var transitionDuration: Double = 0.5
    
    // UI state
    @State private var showFilePicker: Bool = false
    @State private var showPreview: Bool = false
    @State private var importError: String?
    @State private var hasImported: Bool = false
    
    // Brand settings for preview background
    @ObservedObject private var brandManager = BrandSettingsManager.shared
    
    private var isEditing: Bool { editingIndex != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Import Section
                Section {
                    if hasImported {
                        // File imported successfully
                        HStack {
                            Image(systemName: "doc.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(filename)
                                    .font(.headline)
                                
                                Text("\(htmlContent.count) characters")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                showFilePicker = true
                            } label: {
                                Text("Replace")
                                    .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        // No file yet
                        VStack(spacing: 16) {
                            Image(systemName: "doc.badge.arrow.up")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            Text("Import an HTML File")
                                .font(.headline)
                            
                            Text("Select an .html file from your device to display in your playlist.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                showFilePicker = true
                            } label: {
                                Label("Choose File", systemImage: "folder")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 20)
                    }
                    
                    if let error = importError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Label("HTML File", systemImage: "doc.text.fill")
                } footer: {
                    Text("The HTML file will be copied to the app and displayed full-screen.")
                }
                
                // MARK: - Settings
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Display Duration")
                            Spacer()
                            Text("\(Int(duration)) seconds")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $duration, in: 5...120, step: 1)
                    }
                    
                    TextField("Item name in playlist", text: $itemName)
                        .onChange(of: itemName) { _, _ in
                            // Keep itemName in sync if user hasn't customized it
                        }
                } header: {
                    Label("Settings", systemImage: "gearshape")
                }
                
                // MARK: - Transition
                TransitionPickerSection(transition: $transition, transitionDuration: $transitionDuration)
                
                // MARK: - Preview
                if hasImported {
                    Section {
                        Button {
                            showPreview = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Preview HTML", systemImage: "eye")
                                Spacer()
                            }
                        }
                        
                        // Mini preview
                        HTMLMiniPreview(htmlContent: htmlContent)
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets())
                    } header: {
                        Label("Preview", systemImage: "rectangle.on.rectangle")
                    }
                }
                
                // MARK: - HTML Tips
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        TipRow(icon: "checkmark.circle.fill", color: .green, text: "Use viewport meta tag for proper scaling")
                        TipRow(icon: "checkmark.circle.fill", color: .green, text: "Inline CSS and JavaScript work best")
                        TipRow(icon: "checkmark.circle.fill", color: .green, text: "Test with dark backgrounds for TV display")
                        TipRow(icon: "exclamationmark.triangle.fill", color: .orange, text: "External resources may not load")
                    }
                    .padding(.vertical, 8)
                } header: {
                    Label("Tips", systemImage: "lightbulb")
                }
            }
            .navigationTitle(isEditing ? "Edit HTML" : "Custom HTML")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add to Playlist") {
                        if isEditing {
                            updateItem()
                        } else {
                            addToPlaylist()
                        }
                        dismiss()
                    }
                    .disabled(!hasImported)
                }
            }
            .onAppear {
                loadExistingData()
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType.html, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showPreview) {
                HTMLFullPreview(htmlContent: htmlContent)
            }
        }
    }
    
    // MARK: - Load Existing
    
    private func loadExistingData() {
        if let existingFilename = existingFilename {
            filename = existingFilename
            
            // Try playlist's media folder first, then fallback to global
            var fileURL: URL?
            
            if let playlistMediaFolder = playlistManager.mediaFolderURL {
                let playlistURL = playlistMediaFolder.appendingPathComponent(existingFilename)
                if FileManager.default.fileExists(atPath: playlistURL.path) {
                    fileURL = playlistURL
                }
            }
            
            // Fallback to global media folder (for backwards compatibility)
            if fileURL == nil, let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let globalURL = docsURL.appendingPathComponent("SuperLooper/media/\(existingFilename)")
                if FileManager.default.fileExists(atPath: globalURL.path) {
                    fileURL = globalURL
                }
            }
            
            if let fileURL = fileURL, let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                htmlContent = content
                hasImported = true
            }
        }
        
        if let index = editingIndex, index < playlistManager.items.count {
            let item = playlistManager.items[index]
            itemName = item.name
            duration = item.duration
            transition = item.transition.normalized
            transitionDuration = item.transitionDuration
        }
    }
    
    // MARK: - File Import
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        importError = nil
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                htmlContent = content
                filename = url.lastPathComponent
                hasImported = true
                
                // Default item name to filename without extension
                if itemName.isEmpty {
                    itemName = url.deletingPathExtension().lastPathComponent
                }
            } catch {
                importError = "Failed to read file: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            importError = "Failed to open file: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Save File
    
    private func saveHTMLToDocuments() -> String? {
        // Use playlist's media folder if available
        let mediaFolder: URL
        if let playlistMediaFolder = playlistManager.mediaFolderURL {
            mediaFolder = playlistMediaFolder
        } else {
            // Fallback to global folder (shouldn't happen in normal use)
            guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            mediaFolder = docsURL.appendingPathComponent("SuperLooper/media")
        }
        
        // Create folder if needed
        try? FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
        
        // Generate unique filename if needed
        var saveFilename = filename
        if !isEditing || existingFilename != filename {
            let baseName = filename.replacingOccurrences(of: ".html", with: "")
            saveFilename = "\(baseName)_\(UUID().uuidString.prefix(8)).html"
        }
        
        let fileURL = mediaFolder.appendingPathComponent(saveFilename)
        
        do {
            try htmlContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return saveFilename
        } catch {
            print("Failed to save HTML: \(error)")
            return nil
        }
    }
    
    // MARK: - Actions
    
    private func addToPlaylist() {
        guard let savedFilename = saveHTMLToDocuments() else { return }
        
        let name = itemName.isEmpty ? filename : itemName
        
        let item = PlaylistItem(
            name: name,
            contentType: .customHTML(filename: savedFilename),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
        
        playlistManager.addItem(item)
        playlistManager.savePlaylist()
    }
    
    private func updateItem() {
        guard let index = editingIndex else { return }
        guard let savedFilename = saveHTMLToDocuments() else { return }
        
        let name = itemName.isEmpty ? filename : itemName
        
        playlistManager.items[index].name = name
        playlistManager.items[index].contentType = .customHTML(filename: savedFilename)
        playlistManager.items[index].duration = duration
        playlistManager.items[index].transition = transition
        playlistManager.items[index].transitionDuration = transitionDuration
        playlistManager.savePlaylist()
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Mini Preview

struct HTMLMiniPreview: View {
    let htmlContent: String
    
    var body: some View {
        HTMLPreviewWebView(html: htmlContent)
            .cornerRadius(12)
            .padding(8)
    }
}

// MARK: - Full Preview

struct HTMLFullPreview: View {
    let htmlContent: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            HTMLPreviewWebView(html: htmlContent)
                .ignoresSafeArea()
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8), .black.opacity(0.3))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - HTML Preview WebView

import WebKit

struct HTMLPreviewWebView: UIViewRepresentable {
    let html: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Preview

#Preview {
    CustomHTMLEditorView(playlistManager: PlaylistManager(items: []))
}
