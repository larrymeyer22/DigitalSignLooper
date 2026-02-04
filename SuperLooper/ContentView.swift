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
    @State private var editablePlaylistName: String = ""
    
    // Edit sheet state
    @State private var showEditSheet = false
    @State private var showCrawlEditor = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Main content area
                HStack(spacing: 0) {
                    // Playlist sidebar
                    if showSidebar {
                        PlaylistSidebarView(
                            playlistManager: playlistManager, 
                            playlistName: $editablePlaylistName,
                            selectedPhotoItems: $selectedPhotoItems,
                            isEditing: $isEditingPlaylist,
                            selectedItemIndex: $selectedItemIndex,
                            showEditSheet: $showEditSheet,
                            onExit: onExit,
                            onRename: { newName in
                                let correctedName = PlaylistStorageManager.shared.renamePlaylist(playlist, to: newName)
                                editablePlaylistName = correctedName
                            }
                        )
                        .frame(width: 300)
                    }
                    
                    // Content display area
                    GeometryReader { contentGeo in
                        // Calculate 16:9 content area dimensions
                        let contentWidth = contentGeo.size.width
                        let contentHeight = contentGeo.size.height
                        let aspectRatio: CGFloat = 16.0 / 9.0
                        
                        // Fit 16:9 within available space
                        let fitWidth = min(contentWidth, contentHeight * aspectRatio)
                        let fitHeight = fitWidth / aspectRatio
                        
                        ZStack {
                            // Always show content on iPad
                            ContentDisplayView(playlistManager: playlistManager)
                            
                            // CRAWL OVERLAY - positioned within 16:9 content area
                            if playlistManager.shouldShowCrawl {
                                VStack {
                                    Spacer()
                                    CrawlView(
                                        data: playlistManager.crawlData,
                                        brandSettings: playlistManager.brandSettings,
                                        containerHeight: fitHeight
                                    )
                                }
                                .frame(width: fitWidth, height: fitHeight)
                            }
                            
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
                                    ControlPanelView(playlistManager: playlistManager, showSidebar: $showSidebar, showCrawlEditor: $showCrawlEditor)
                                        .padding()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedItemIndex)
        .animation(.easeInOut(duration: 0.3), value: showSidebar)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            // Set current playlist for media folder paths
            playlistManager.currentPlaylist = playlist
            // Sync FileSystemManager to use this playlist's folder
            FileSystemManager.shared.switchToPlaylist(named: playlist.name)
            // Initialize editable name
            editablePlaylistName = playlist.name
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
            SettingsView(playlistManager: playlistManager, playlistName: editablePlaylistName, onExit: onExit)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showCrawlEditor) {
            CrawlEditorSheet(playlistManager: playlistManager)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            selectedItemIndex = nil
        }) {
            if let index = selectedItemIndex, index < playlistManager.items.count {
                let item = playlistManager.items[index]
                editorView(for: item, at: index)
                    .preferredColorScheme(.dark)
                    .presentationDetents([.large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .large))
                    .presentationBackground(.ultraThickMaterial)
            }
        }
        .onChange(of: selectedItemIndex) { _, newIndex in
            if isEditingPlaylist, let index = newIndex {
                playlistManager.jumpTo(index: index)
            }
        }
    }
    
    // MARK: - Editor View Builder
    
    @ViewBuilder
    private func editorView(for item: PlaylistItem, at index: Int) -> some View {
        switch item.contentType {
        case .titleSlide(let data):
            TitleSlideEditorView(playlistManager: playlistManager, editingIndex: index, existingData: data)
        case .featuredPerson(let data):
            FeaturedPersonEditorView(playlistManager: playlistManager, editingIndex: index, existingData: data)
        case .schedule(let data):
            ScheduleEditorView(playlistManager: playlistManager, editingIndex: index, existingData: data)
        case .liveWeb(let url, _):
            LiveWebsiteEditorView(playlistManager: playlistManager, editingIndex: index, existingURL: url)
        case .countdown(let data):
            CountdownEditorView(playlistManager: playlistManager, editingIndex: index, existingData: data)
        case .weather(let data):
            WeatherEditorView(playlistManager: playlistManager, editingIndex: index, existingData: data)
        case .leaderboard(let data):
            LeaderboardEditorView(playlistManager: playlistManager, editingIndex: index, existingData: data)
        case .image, .video:
            // Media item editor with duration
            MediaItemEditorView(playlistManager: playlistManager, itemIndex: index)
        default:
            // For other types, show basic info
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: item.contentType.iconName)
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Duration: \(Int(item.duration))s")
                        .foregroundColor(.secondary)
                }
                .navigationTitle("Item Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showEditSheet = false }
                    }
                }
            }
        }
    }
    
    // MARK: - Streamlined Import
    
    private func importSelectedMedia(_ items: [PhotosPickerItem]) {
        guard !isImporting else { return }
        isImporting = true
        
        Task {
            var successCount = 0
            
            // Get playlist media folder
            guard let mediaFolder = playlistManager.mediaFolderURL else {
                print("⚠️ No media folder available")
                await MainActor.run {
                    selectedPhotoItems = []
                    isImporting = false
                }
                return
            }
            
            // Ensure media folder exists
            try? FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
            
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
                        let destURL = mediaFolder.appendingPathComponent(filename)
                        
                        do {
                            try FileManager.default.copyItem(at: movie.url, to: destURL)
                            let playlistItem = PlaylistItem(
                                name: filename,
                                contentType: .video(filename: filename),
                                duration: videoDuration
                            )
                            await MainActor.run {
                                playlistManager.addItem(playlistItem)
                            }
                            successCount += 1
                        } catch {
                            print("Failed to copy video: \(error)")
                        }
                    }
                    // Then try image
                    else if let data = try await item.loadTransferable(type: Data.self),
                            let image = UIImage(data: data) {
                        let filename = "image_\(UUID().uuidString.prefix(8)).jpg"
                        let destURL = mediaFolder.appendingPathComponent(filename)
                        
                        if let jpegData = image.jpegData(compressionQuality: 0.9) {
                            do {
                                try jpegData.write(to: destURL)
                                let playlistItem = PlaylistItem(
                                    name: filename,
                                    contentType: .image(filename: filename)
                                )
                                await MainActor.run {
                                    playlistManager.addItem(playlistItem)
                                }
                                successCount += 1
                            } catch {
                                print("Failed to save image: \(error)")
                            }
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
    @State private var selectedTransitionType: TransitionType = .dissolve
    @State private var showClearConfirm = false
    @State private var showExitConfirm = false
    @State private var showBrandSettings = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showExportError = false
    @State private var exportErrorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            settingsForm
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { doneButton }
                .onAppear {
                    transitionDuration = playlistManager.transitionDuration
                    selectedTransitionType = (playlistManager.items.first?.transition ?? .dissolve).normalized
                }
                .alert("Clear Playlist?", isPresented: $showClearConfirm) { clearAlert }
                .alert("Switch Playlist?", isPresented: $showExitConfirm) { switchAlert }
                .alert("Export Error", isPresented: $showExportError) {
                    Button("OK") { }
                } message: {
                    Text(exportErrorMessage)
                }
                .sheet(isPresented: $showBrandSettings) { BrandSettingsView().preferredColorScheme(.dark) }
                .sheet(isPresented: $showExportSheet) { shareSheet }
        }
    }
    
    private var settingsForm: some View {
        Form {
            currentPlaylistSection
            playbackSection
            appearanceSection
            shareSection
            switchSection
            clearSection
        }
    }
    
    private var currentPlaylistSection: some View {
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
    }
    
    private var playbackSection: some View {
        Section("Playback") {
            // Transition style picker
            Picker("Transition Style", selection: $selectedTransitionType) {
                ForEach(TransitionType.availableCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName)
                        .tag(type)
                }
            }
            .onChange(of: selectedTransitionType) { _, newValue in
                for i in playlistManager.items.indices {
                    playlistManager.items[i].transition = newValue
                }
                playlistManager.savePlaylistToDisk()
            }
            
            // Duration slider (hidden for cut since it's instant)
            if selectedTransitionType != .cut {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Transition Duration")
                        Spacer()
                        Text(String(format: "%.1fs", transitionDuration))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $transitionDuration, in: 0.2...2.0, step: 0.1)
                        .onChange(of: transitionDuration) { _, newValue in
                            playlistManager.transitionDuration = newValue
                        }
                }
            }
        }
    }
    
    private var appearanceSection: some View {
        Section("Appearance") {
            Button { showBrandSettings = true } label: {
                HStack {
                    Image(systemName: "paintpalette").foregroundColor(.purple)
                    Text("Brand Settings").foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var shareSection: some View {
        Section {
            Button { exportPlaylist() } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up").foregroundColor(.green)
                    Text("Export Playlist").foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Share")
        } footer: {
            Text("Export this playlist as a zip file to share or backup.")
        }
    }
    
    private var switchSection: some View {
        Section {
            Button { showExitConfirm = true } label: {
                HStack {
                    Image(systemName: "rectangle.stack")
                    Text("Switch Playlist")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var clearSection: some View {
        Section {
            Button(role: .destructive) { showClearConfirm = true } label: {
                HStack {
                    Spacer()
                    Text("Clear All Items")
                    Spacer()
                }
            }
        }
    }
    
    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
                playlistManager.transitionDuration = transitionDuration
                dismiss()
            }
        }
    }
    
    @ViewBuilder
    private var clearAlert: some View {
        Button("Cancel", role: .cancel) { }
        Button("Clear All", role: .destructive) {
            playlistManager.clearPlaylist()
            dismiss()
        }
    }
    
    @ViewBuilder
    private var switchAlert: some View {
        Button("Cancel", role: .cancel) { }
        Button("Switch") {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onExit() }
        }
    }
    
    @ViewBuilder
    private var shareSheet: some View {
        if let url = exportURL {
            ShareSheet(activityItems: [url])
        }
    }
    
    private func exportPlaylist() {
        guard let playlist = playlistManager.currentPlaylist else {
            exportErrorMessage = "No playlist loaded"
            showExportError = true
            return
        }
        
        do {
            let url = try PlaylistStorageManager.shared.exportPlaylist(playlist)
            exportURL = url
            showExportSheet = true
        } catch {
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Content View Snapshot Capture
//
// Transparent overlay that registers its parent UIView with PlaylistManager
// so we can snapshot the current content before transitions (prevents web content flash)

struct ContentViewCapture: UIViewRepresentable {
    weak var playlistManager: PlaylistManager?
    let isExternal: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Register the parent container (which holds the actual content view alongside us)
        // so PlaylistManager can snapshot it before transitions
        DispatchQueue.main.async {
            guard let container = uiView.superview else { return }
            if self.isExternal {
                self.playlistManager?._externalContentView = container
            } else {
                self.playlistManager?._iPadContentView = container
            }
        }
    }
}

// MARK: - Content Display View with Seamless Crossfade

struct ContentDisplayView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @ObservedObject private var brandManager = BrandSettingsManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            let availableSize = geometry.size
            let aspectRatio: CGFloat = 16.0 / 9.0
            
            // Calculate 16:9 frame that fits within available space
            let previewSize: CGSize = {
                let widthBasedHeight = availableSize.width / aspectRatio
                let heightBasedWidth = availableSize.height * aspectRatio
                
                if widthBasedHeight <= availableSize.height {
                    // Width is the constraint
                    return CGSize(width: availableSize.width, height: widthBasedHeight)
                } else {
                    // Height is the constraint
                    return CGSize(width: heightBasedWidth, height: availableSize.height)
                }
            }()
            
            // Transition animation helpers
            let transType = playlistManager.activeTransitionType
            let transDur = playlistManager.transitionDuration
            let isT = playlistManager.isTransitioning
            let hasPrev = playlistManager.previousItem != nil
            let w = previewSize.width
            
            // Previous item (curtain): how it exits
            let prevOpacity: Double = {
                guard isT else { return 1.0 }
                switch transType {
                case .pushLeft, .pushRight: return 1.0  // stays visible while sliding
                default: return 0.0  // fades out for dissolve/cut
                }
            }()
            let prevOffsetX: CGFloat = {
                guard isT else { return 0 }
                switch transType {
                case .pushLeft: return -w
                case .pushRight: return w
                default: return 0
                }
            }()
            
            // Current item: how it enters (only moves for push)
            let currOffsetX: CGFloat = {
                guard hasPrev else { return 0 }  // no transition active
                switch transType {
                case .pushLeft: return isT ? 0 : w     // slides in from right
                case .pushRight: return isT ? 0 : -w   // slides in from left
                default: return 0  // dissolve/cut: sits at 0 under curtain
                }
            }()
            
            // Animation curve
            let transAnimation: Animation = {
                switch transType {
                case .cut: return .linear(duration: 0)
                case .pushLeft, .pushRight: return .easeInOut(duration: transDur)
                default: return .linear(duration: transDur)
                }
            }()
            
            ZStack {
                // Black background for letterbox bars
                Color.black
                
                // 16:9 content area
                ZStack {
                    Color.black
                    
                    // Current item (underneath) — loads in background, slides in for push
                    if let item = playlistManager.currentItem {
                        ZStack {
                            contentView(for: item, isOutgoing: false)
                            ContentViewCapture(playlistManager: playlistManager, isExternal: false)
                        }
                        .id("current-\(item.id)")
                        .offset(x: currOffsetX)
                        .animation(transAnimation, value: playlistManager.isTransitioning)
                    }
                    
                    // Previous item (on top) — curtain: fades for dissolve, slides for push, snaps for cut
                    if let previous = playlistManager.previousItem {
                        contentView(for: previous, isOutgoing: true)
                            .id("previous-\(previous.id)")
                            .opacity(prevOpacity)
                            .offset(x: prevOffsetX)
                            .animation(transAnimation, value: playlistManager.isTransitioning)
                    }
                    
                    // Empty state
                    if playlistManager.currentItem == nil && playlistManager.previousItem == nil {
                        emptyStateView
                    }
                }
                .frame(width: previewSize.width, height: previewSize.height)
                .clipped()
            }
            .frame(width: availableSize.width, height: availableSize.height)
        }
    }
    
    @ViewBuilder
    private func contentView(for item: PlaylistItem, isOutgoing: Bool) -> some View {
        // For outgoing web content, use a pre-captured snapshot instead of
        // creating a new WKWebView (which causes a flash while it loads)
        if isOutgoing,
           let snapshot = playlistManager.outgoingWebSnapshot,
           PlaylistManager.isWebBased(item.contentType) {
            ZStack {
                Color.black
                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        } else {
            standardContentView(for: item, isOutgoing: isOutgoing)
        }
    }
    
    @ViewBuilder
    private func standardContentView(for item: PlaylistItem, isOutgoing: Bool) -> some View {
        switch item.contentType {
        case .image(let filename):
            if isOutgoing {
                // Use cached outgoing image for instant rendering (no load delay)
                ImageContentView(filename: filename, preloadedImage: playlistManager.outgoingImage)
            } else {
                ImageContentView(filename: filename, preloadedImage: playlistManager.preloadedImageFilename == filename ? playlistManager.preloadedImage : nil)
            }
            
        case .video(let filename):
            // Use outgoing snapshot for instant-render curtain, fall back to live player
            if isOutgoing {
                if let snapshot = playlistManager.outgoingVideoSnapshot {
                    ZStack {
                        Color.black
                        Image(uiImage: snapshot)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                } else {
                    OutgoingVideoView(player: playlistManager.outgoingVideoPlayer)
                }
            } else {
                VideoContentView(filename: filename, playlistManager: playlistManager)
            }
            
        case .html(let content):
            HTMLContentView(htmlContent: content)
            
        case .web(let url):
            WebContentView(url: url)
            
        case .titleSlide(let data):
            TemplateHTMLView(html: TitleSlideRenderer.render(data: data, brandSettings: brandManager.settings))
                .id("titleSlide-\(brandManager.settings.settingsHash)")
            
        case .featuredPerson(let data):
            FeaturedPersonTemplateView(data: data, brandSettings: brandManager.settings)
                .id("featuredPerson-\(brandManager.settings.settingsHash)")
            
        case .schedule(let data):
            TemplateHTMLView(html: ScheduleRenderer.render(data: data, brandSettings: brandManager.settings))
                .id("schedule-\(brandManager.settings.settingsHash)")
            
        case .leaderboard(let data):
            TemplateHTMLView(html: LeaderboardRenderer.render(data: data, brandSettings: brandManager.settings))
                .id("leaderboard-\(brandManager.settings.settingsHash)")
            
        case .countdown(let data):
            TemplateHTMLView(html: CountdownRenderer.render(data: data, brandSettings: brandManager.settings))
                .id("countdown-\(brandManager.settings.settingsHash)-\(data.mode)")
            
        case .weather(let data):
            WeatherContentView(data: data, brandSettings: brandManager.settings)
                .id("weather-\(data.latitude)-\(data.longitude)-\(brandManager.settings.settingsHash)")
            
        case .liveWeb(let url, _):
            WebContentView(url: url)
            
        case .customHTML(let filename):
            CustomHTMLFileView(filename: filename)
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
    @Binding var playlistName: String
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var isEditing: Bool
    @Binding var selectedItemIndex: Int?
    @Binding var showEditSheet: Bool
    var onExit: () -> Void
    var onRename: (String) -> Void = { _ in }
    @State private var showContentTemplates = false
    
    // Helper to check if content type is editable
    private func isContentEditable(_ contentType: ContentType) -> Bool {
        switch contentType {
        case .titleSlide, .featuredPerson, .schedule, .liveWeb, .customHTML, .countdown, .weather, .image, .video, .leaderboard:
            return true
        default:
            return false
        }
    }
    
    private var totalDuration: TimeInterval {
        playlistManager.items.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        TextField("Playlist Name", text: $playlistName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                    } else {
                        Text(playlistName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
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
                        if isEditing {
                            // Exiting edit mode - save the name and dismiss any open sheet
                            onRename(playlistName)
                            showEditSheet = false
                        }
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
                    
                    // Content Templates
                    Button(action: {
                        showContentTemplates = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.title3)
                                .foregroundColor(.purple)
                            
                            Text("Content Templates")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.purple.opacity(0.1))
                    }
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
                            isEditable: isContentEditable(item.contentType),
                            onDelete: {
                                withAnimation {
                                    if selectedItemIndex == index {
                                        selectedItemIndex = nil
                                    }
                                    playlistManager.removeItem(at: index)
                                }
                            },
                            onEdit: {
                                selectedItemIndex = index
                                playlistManager.jumpTo(index: index)
                                showEditSheet = true
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onTapGesture {
                            selectedItemIndex = index
                            playlistManager.jumpTo(index: index)
                            showEditSheet = true
                        }
                    }
                    .onMove { from, to in
                        playlistManager.moveItem(from: from, to: to)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else if playlistManager.items.isEmpty {
                // Empty playlist - prompt to enter edit mode
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Playlist is empty")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.body)
                            Text("Add Content")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
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
            
            // Back to Playlists button at bottom
            Divider()
                .background(Color.white.opacity(0.2))
            
            Button(action: onExit) {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.subheadline)
                    Text("Back to Playlists")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.black.opacity(0.85))
        .sheet(isPresented: $showContentTemplates) {
            ContentTemplatesView(playlistManager: playlistManager)
                .preferredColorScheme(.dark)
        }
    }
    
    private func formatTotalDuration(_ seconds: TimeInterval) -> String {
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
    var isEditable: Bool = false
    var onDelete: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    
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
                
                HStack(spacing: 6) {
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
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Image(systemName: item.transition.normalized.iconName)
                        .font(.caption2)
                        .foregroundColor(.gray)
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
                // Always-present background — changes fill instead of adding/removing views
                // to prevent orphan rectangles from SwiftUI animation bugs
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEditing ? Color(white: 0.2) : (isActive ? Color.blue.opacity(0.15) : Color.clear))
                
                // Progress bar (only for active item in playback mode)
                if isActive && !isEditing {
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
    @Binding var showCrawlEditor: Bool
    
    @State private var showDisplayTip = false
    
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
            
            // Row 3: Crawl toggle + External display indicator
            HStack(spacing: 24) {
                // Crawl button - always opens editor
                Button(action: {
                    showCrawlEditor = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.redaction")
                            .font(.system(size: 18))
                        Text("Crawl")
                            .font(.subheadline)
                    }
                    .foregroundColor(playlistManager.shouldShowCrawl ? .green : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // External display indicator with tooltip
                Button(action: {
                    showDisplayTip = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "tv.fill")
                            .font(.system(size: 16))
                        Text("Display")
                            .font(.subheadline)
                    }
                    .foregroundColor(ExternalDisplayManager.shared.isConnected ? .green : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDisplayTip) {
                    Text("Swipe down in the upper right corner of the screen to manage screen mirroring.")
                        .font(.subheadline)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            
            // Row 4: Media name + position
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

// MARK: - Media Item Editor (Images & Videos)

struct MediaItemEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    let itemIndex: Int
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var itemName: String = ""
    @State private var duration: Double = 10
    @State private var isVideo: Bool = false
    @State private var itemTransition: TransitionType = .dissolve
    
    private var item: PlaylistItem? {
        guard itemIndex < playlistManager.items.count else { return nil }
        return playlistManager.items[itemIndex]
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Preview section
                if let item = item {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: item.contentType.iconName)
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue)
                                
                                Text(item.contentType.typeName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    }
                }
                
                // Name
                Section {
                    TextField("Display Name", text: $itemName)
                        .onChange(of: itemName) { _, newValue in
                            playlistManager.updateItemName(at: itemIndex, name: newValue)
                        }
                } header: {
                    Text("Display Name")
                }
                
                // Duration (only for images)
                if !isVideo {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Duration")
                                Spacer()
                                Text("\(Int(duration)) seconds")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $duration, in: 3...120, step: 1)
                                .onChange(of: duration) { _, newValue in
                                    playlistManager.updateItemDuration(at: itemIndex, duration: newValue)
                                }
                        }
                    } header: {
                        Text("Display Duration")
                    } footer: {
                        Text("How long this image displays before advancing")
                    }
                } else {
                    Section {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(formatDuration(duration))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Video Duration")
                    } footer: {
                        Text("Video plays for its full length")
                    }
                }
                
                // Transition picker
                Section {
                    Picker("Transition", selection: $itemTransition) {
                        ForEach(TransitionType.availableCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .onChange(of: itemTransition) { _, newValue in
                        guard itemIndex < playlistManager.items.count else { return }
                        playlistManager.items[itemIndex].transition = newValue
                        playlistManager.savePlaylistToDisk()
                    }
                } header: {
                    Text("Transition")
                } footer: {
                    Text("Animation when leaving this item")
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadItemData()
            }
        }
    }
    
    private func loadItemData() {
        guard let item = item else { return }
        itemName = item.name
        duration = item.duration
        itemTransition = item.transition.normalized
        
        if case .video = item.contentType {
            isVideo = true
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview(traits: .landscapeLeft) {
    ContentView(playlist: PlaylistInfo.sample, onExit: {})
}
