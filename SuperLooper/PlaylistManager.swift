//
//  PlaylistManager.swift
//  Super Looper
//
//  REVISED: Crawl is now a playlist-level setting, not a content item
//  Changes marked with // CRAWL REVISION
//

import Foundation
import Combine
import SwiftUI
import AVFoundation
import WebKit
import WebKit

/// Manages the playback of a playlist
@MainActor
class PlaylistManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var items: [PlaylistItem] = []
    @Published var currentIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var currentProgress: Double = 0.0
    @Published var timeRemaining: TimeInterval = 0.0
    @Published var transitionDuration: TimeInterval = 1.0
    @Published var sharedVideoPlayer: AVPlayer?
    @Published var outgoingVideoPlayer: AVPlayer?
    @Published var outgoingImage: UIImage?
    @Published var outgoingVideoSnapshot: UIImage?
    @Published var outgoingVideoSnapshotExternal: UIImage?
    @Published var outgoingWebSnapshot: UIImage?
    @Published var outgoingWebSnapshotExternal: UIImage?
    @Published var isVideoReady: Bool = false
    @Published var previousItem: PlaylistItem?
    @Published var isTransitioning: Bool = false
    @Published var activeTransitionType: TransitionType = .dissolve
    @Published var preloadedImage: UIImage?
    @Published var preloadedImageFilename: String?
    
    // CRAWL REVISION: Crawl is now a playlist-level property
    @Published var crawlData: CrawlData = CrawlData()
    
    // MARK: - Current Playlist Info
    
    /// The current playlist being managed (for saving media to correct folder)
    var currentPlaylist: Playlist?
    
    /// Brand settings for templates (loaded from BrandSettingsManager)
    var brandSettings: BrandSettings? {
        return BrandSettingsManager.shared.settings
    }
    
    /// URL to the media folder for the current playlist
    var mediaFolderURL: URL? {
        guard let playlist = currentPlaylist else { return nil }
        return PlaylistStorageManager.shared.mediaFolderURL(for: playlist)
    }
    
    // CRAWL REVISION: Removed activeCrawl computed property that looked for crawl items
    // Now we simply check if crawlData.isEnabled && crawlData.hasContent
    
    /// Quick check if crawl should be displayed
    var shouldShowCrawl: Bool {
        crawlData.isEnabled && crawlData.hasContent
    }
    
    // MARK: - Media URL Resolution
    
    /// Get video URL - checks playlist folder first, then falls back to global
    func videoURL(for filename: String) -> URL {
        // First check playlist's media folder
        if let mediaFolder = mediaFolderURL {
            let playlistURL = mediaFolder.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: playlistURL.path) {
                return playlistURL
            }
        }
        
        // Fall back to global FileSystemManager
        return FileSystemManager.shared.videoURL(for: filename)
    }
    
    /// Get image URL - checks playlist folder first, then falls back to global
    func imageURL(for filename: String) -> URL {
        // First check playlist's media folder
        if let mediaFolder = mediaFolderURL {
            let playlistURL = mediaFolder.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: playlistURL.path) {
                return playlistURL
            }
        }
        
        // Fall back to global FileSystemManager
        return FileSystemManager.shared.imageURL(for: filename)
    }
    
    /// Load image - checks playlist folder first, then falls back to global
    func loadImage(filename: String) -> UIImage? {
        print("🖼️ loadImage called for: \(filename)")
        print("   currentPlaylist: \(currentPlaylist?.name ?? "nil")")
        
        // First check playlist's media folder
        if let mediaFolder = mediaFolderURL {
            let playlistURL = mediaFolder.appendingPathComponent(filename)
            print("   Checking playlist path: \(playlistURL.path)")
            print("   File exists: \(FileManager.default.fileExists(atPath: playlistURL.path))")
            if let image = UIImage(contentsOfFile: playlistURL.path) {
                print("   ✅ Found in playlist folder")
                return image
            }
        } else {
            print("   ⚠️ mediaFolderURL is nil")
        }
        
        // Fall back to global FileSystemManager
        print("   Falling back to FileSystemManager")
        return FileSystemManager.shared.loadImage(filename: filename)
    }
    
    /// Save image to playlist's media folder
    func saveImage(_ image: UIImage, filename: String) -> URL? {
        guard let mediaFolder = mediaFolderURL else {
            // Fall back to global if no playlist
            return FileSystemManager.shared.saveImage(image, filename: filename)
        }
        
        // Ensure folder exists
        try? FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
        
        let fileURL = mediaFolder.appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.9) {
            do {
                try data.write(to: fileURL)
                return fileURL
            } catch {
                print("Failed to save image: \(error)")
            }
        }
        return nil
    }
    
    // MARK: - Private Properties
    
    private var preloadedVideoPlayer: AVPlayer?
    private var preloadedVideoFilename: String?
    private var timer: AnyCancellable?
    private var itemStartTime: Date?
    private var currentItemDuration: TimeInterval = 0
    private var videoPlayerCancellables = Set<AnyCancellable>()
    private var preloadedVideoPlayerCancellables = Set<AnyCancellable>()
    private var transitionWorkItem: DispatchWorkItem?
    private var transitionRevealWorkItem: DispatchWorkItem?
    private let timerInterval: TimeInterval = 0.1
    
    // MARK: - Snapshot Capture References
    // Registered by ContentViewCapture overlay in ContentDisplayView / ExternalScreenView
    weak var _iPadContentView: UIView?
    weak var _externalContentView: UIView?
    
    // MARK: - Computed Properties
    
    var currentItem: PlaylistItem? {
        guard !items.isEmpty, currentIndex >= 0, currentIndex < items.count else {
            return nil
        }
        return items[currentIndex]
    }
    
    var nextItem: PlaylistItem? {
        guard !items.isEmpty else { return nil }
        let nextIndex = (currentIndex + 1) % items.count
        return items[nextIndex]
    }
    
    var hasItems: Bool { !items.isEmpty }
    var itemCount: Int { items.count }
    
    // MARK: - Initialization
    
    init(items: [PlaylistItem] = []) {
        self.items = items
    }
    
    // MARK: - Preloading
    
    func preloadNextItem() {
        guard let next = nextItem else { return }
        
        switch next.contentType {
        case .image(let filename):
            if preloadedImageFilename != filename {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    let image = self.loadImage(filename: filename)
                    self.preloadedImage = image
                    self.preloadedImageFilename = filename
                }
            }
        case .video(let filename):
            if preloadedVideoFilename != filename {
                preloadVideo(filename: filename)
            }
        default:
            break
        }
    }
    
    private func preloadVideo(filename: String) {
        let url = videoURL(for: filename)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Video file not found for preload: \(url.path)")
            return
        }
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = .pause
        player.allowsExternalPlayback = false
        player.preventsDisplaySleepDuringVideoPlayback = true
        
        preloadedVideoPlayerCancellables.removeAll()
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.videoDidFinish()
            }
            .store(in: &preloadedVideoPlayerCancellables)
        
        preloadedVideoPlayer = player
        preloadedVideoFilename = filename
        
        // Wait for player to be ready before prerolling
        playerItem.publisher(for: \.status)
            .filter { $0 == .readyToPlay }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak player] _ in
                player?.preroll(atRate: 1.0) { success in
                    print("✅ Preloaded video: \(filename), preroll: \(success)")
                }
            }
            .store(in: &preloadedVideoPlayerCancellables)
    }
    
    // MARK: - Playback Controls
    
    func play() {
        guard hasItems else { return }
        
        isPlaying = true
        itemStartTime = Date()
        
        if let item = currentItem {
            if item.contentType.hasFixedDuration {
                // Video - duration comes from video file
                // Don't overwrite if player is already set up and duration loaded
                if sharedVideoPlayer == nil {
                    currentItemDuration = 0
                    timeRemaining = 0
                } else {
                    // Player exists - start playing it
                    sharedVideoPlayer?.play()
                    // Keep existing duration if already loaded
                    if currentItemDuration > 0 {
                        timeRemaining = currentItemDuration
                    }
                }
            } else {
                // Non-video - use item.duration
                currentItemDuration = item.duration
                timeRemaining = currentItemDuration
            }
        }
        
        startTimer()
        
        // Preload next item immediately on play
        preloadNextItem()
    }
    
    func pause() {
        isPlaying = false
        stopTimer()
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func next() {
        guard hasItems else { return }
        performTransition {
            self.currentIndex = (self.currentIndex + 1) % self.items.count
        }
    }
    
    func previous() {
        guard hasItems else { return }
        performTransition {
            self.currentIndex = (self.currentIndex - 1 + self.items.count) % self.items.count
        }
    }
    
    func jumpTo(index: Int) {
        guard index >= 0, index < items.count else { return }
        guard index != currentIndex else { return }
        
        performTransition {
            self.currentIndex = index
        }
    }
    
    func jumpTo(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        jumpTo(index: index)
    }
    
    // MARK: - Two-Phase Transition
    //
    // Phase 1: previousItem placed on TOP at full opacity (curtain).
    //          New currentItem loads underneath, invisible to user.
    // Phase 2: After content-appropriate delay, set isTransitioning = true.
    //          previousItem animates out (fade/cut/push) to reveal loaded content.
    // Cleanup: After animation completes, remove previousItem.
    
    private func performTransition(indexChange: @escaping () -> Void) {
        transitionWorkItem?.cancel()
        transitionRevealWorkItem?.cancel()
        
        let outgoingItem = currentItem
        
        let outgoingIsVideo = outgoingItem?.contentType.isVideo ?? false
        
        if outgoingIsVideo {
            outgoingVideoPlayer = sharedVideoPlayer
            sharedVideoPlayer = nil
            // Extract the actual current video frame directly from the player.
            // drawHierarchy can't capture AVPlayerLayer content (GPU path), so we
            // use AVAssetImageGenerator to decode the exact frame at current playback time.
            let frame = Self.captureCurrentVideoFrame(from: outgoingVideoPlayer)
            outgoingVideoSnapshot = frame
            outgoingVideoSnapshotExternal = frame  // same frame for both displays
        } else {
            outgoingVideoSnapshot = nil
            outgoingVideoSnapshotExternal = nil
        }
        
        // Capture outgoing image so the previous overlay can render instantly
        if let outgoingItem = outgoingItem, case .image(let filename) = outgoingItem.contentType {
            outgoingImage = loadImage(filename: filename)
        } else {
            outgoingImage = nil
        }
        
        // Capture outgoing web snapshot so web content curtain renders instantly (no WKWebView reload flash)
        if let outgoingItem = outgoingItem, Self.isWebBased(outgoingItem.contentType) {
            outgoingWebSnapshot = Self.captureViewSnapshot(_iPadContentView, forExternal: false)
            outgoingWebSnapshotExternal = Self.captureViewSnapshot(_externalContentView, forExternal: true)
        } else {
            outgoingWebSnapshot = nil
            outgoingWebSnapshotExternal = nil
        }
        
        // Phase 1: Set previous as curtain BEFORE changing index
        // isTransitioning stays false so previous stays fully opaque on top
        previousItem = outgoingItem
        isTransitioning = false
        activeTransitionType = (outgoingItem?.transition ?? .dissolve).normalized
        
        indexChange()
        
        if let current = currentItem, case .video(let filename) = current.contentType {
            if preloadedVideoFilename == filename, let preloaded = preloadedVideoPlayer {
                sharedVideoPlayer = preloaded
                preloadedVideoPlayer = nil
                preloadedVideoFilename = nil
                
                videoPlayerCancellables = preloadedVideoPlayerCancellables
                preloadedVideoPlayerCancellables = Set<AnyCancellable>()
                
                setupTimeObserver(for: sharedVideoPlayer!)
                
                if let playerItem = sharedVideoPlayer?.currentItem {
                    Task { [weak self] in
                        do {
                            let duration = try await playerItem.asset.load(.duration)
                            let seconds = CMTimeGetSeconds(duration)
                            if seconds.isFinite && seconds > 0 {
                                await MainActor.run {
                                    self?.setCurrentVideoDuration(seconds)
                                }
                            }
                        } catch {
                            print("Failed to load preloaded video duration: \(error)")
                        }
                    }
                }
                
                if isPlaying {
                    sharedVideoPlayer?.play()
                }
                
                isVideoReady = true
                print("✅ Using preloaded video: \(filename)")
            } else {
                preloadedVideoPlayer?.pause()
                preloadedVideoPlayer = nil
                preloadedVideoFilename = nil
                preloadedVideoPlayerCancellables.removeAll()
                isVideoReady = false
                print("⚠️ Preloaded video doesn't match, will load: \(filename)")
            }
        }
        
        resetItemProgress()
        
        if isPlaying {
            itemStartTime = Date()
            if let item = currentItem {
                currentItemDuration = item.contentType.hasFixedDuration ? 0 : item.duration
                timeRemaining = currentItemDuration
            }
            startTimer()
        }
        
        preloadNextItem()
        
        // Phase 2: Schedule the reveal based on content type
        let incomingIsVideo = currentItem?.contentType.isVideo ?? false
        let incomingIsLiveWeb = currentItem?.contentType.isLiveWeb ?? false
        
        let incomingIsImage: Bool = {
            guard let ct = currentItem?.contentType else { return false }
            if case .image = ct { return true }
            return false
        }()
        
        if incomingIsVideo {
            // Wait for video to be ready, then reveal
            scheduleVideoReveal()
        } else if incomingIsImage {
            // Images are fast, especially if preloaded
            let revealItem = DispatchWorkItem { [weak self] in
                self?.startRevealAnimation()
            }
            transitionRevealWorkItem = revealItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: revealItem)
        } else if incomingIsLiveWeb {
            // Live web pages need network time to load
            let revealItem = DispatchWorkItem { [weak self] in
                self?.startRevealAnimation()
            }
            transitionRevealWorkItem = revealItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: revealItem)
        } else {
            // HTML templates/custom HTML — load from local HTML strings, need WKWebView render time
            let revealItem = DispatchWorkItem { [weak self] in
                self?.startRevealAnimation()
            }
            transitionRevealWorkItem = revealItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: revealItem)
        }
    }
    
    /// Phase 2: Trigger the fade animation on the outgoing curtain
    private func startRevealAnimation() {
        isTransitioning = true
        
        // Cleanup: Remove previous after the animation duration completes
        let workItem = DispatchWorkItem { [weak self] in
            self?.previousItem = nil
            self?.isTransitioning = false
            self?.outgoingVideoPlayer?.pause()
            self?.outgoingVideoPlayer = nil
            self?.outgoingImage = nil
            self?.outgoingVideoSnapshot = nil
            self?.outgoingVideoSnapshotExternal = nil
            self?.outgoingWebSnapshot = nil
            self?.outgoingWebSnapshotExternal = nil
        }
        transitionWorkItem = workItem
        let effectiveDuration = activeTransitionType == .cut ? 0 : transitionDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + effectiveDuration + 0.05, execute: workItem)
    }
    
    private func scheduleVideoReveal(attempts: Int = 30) {
        if isVideoReady || attempts <= 0 {
            // Video is "ready" but the AVPlayerLayer may not have rendered its first frame yet.
            // Add a small buffer so the visible frame is painted before the curtain fades away.
            let revealItem = DispatchWorkItem { [weak self] in
                self?.startRevealAnimation()
            }
            transitionRevealWorkItem = revealItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: revealItem)
        } else {
            // Check again in 0.1s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.scheduleVideoReveal(attempts: attempts - 1)
            }
        }
    }
    
    private func setupTimeObserver(for player: AVPlayer) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let item = self.currentItem,
                  item.contentType.hasFixedDuration,
                  self.currentItemDuration > 0 else { return }
            
            let currentTime = CMTimeGetSeconds(time)
            self.currentProgress = min(currentTime / self.currentItemDuration, 1.0)
            self.timeRemaining = max(self.currentItemDuration - currentTime, 0)
        }
    }
    
    // MARK: - Video Completion Handler
    
    func videoDidFinish() {
        if isPlaying {
            next()
        }
    }
    
    func setCurrentVideoDuration(_ duration: TimeInterval) {
        guard currentItem?.contentType.hasFixedDuration == true else { return }
        
        currentItemDuration = duration
        timeRemaining = duration
        itemStartTime = Date()
    }
    
    // MARK: - Shared Video Player Management
    
    func setupSharedVideoPlayer(for filename: String) {
        cleanupSharedVideoPlayer()
        
        let url = videoURL(for: filename)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Video file not found: \(url.path)")
            return
        }
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = .pause
        player.allowsExternalPlayback = false
        player.preventsDisplaySleepDuringVideoPlayback = true
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        Task { [weak self] in
            do {
                let duration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)
                if seconds.isFinite && seconds > 0 {
                    await MainActor.run {
                        self?.setCurrentVideoDuration(seconds)
                    }
                }
            } catch {
                print("Failed to load video duration: \(error)")
            }
        }
        
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.videoDidFinish()
            }
            .store(in: &videoPlayerCancellables)
        
        setupTimeObserver(for: player)
        
        sharedVideoPlayer = player
        
        // Wait for player to be ready, then preroll and play
        playerItem.publisher(for: \.status)
            .filter { $0 == .readyToPlay }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak player] _ in
                guard let self = self, let player = player else { return }
                player.preroll(atRate: 1.0) { [weak self, weak player] success in
                    DispatchQueue.main.async {
                        guard let self = self, let player = player else { return }
                        if self.isPlaying {
                            player.play()
                        }
                        self.isVideoReady = true
                    }
                }
            }
            .store(in: &videoPlayerCancellables)
        
        preloadNextItem()
    }
    
    func cleanupSharedVideoPlayer() {
        sharedVideoPlayer?.pause()
        sharedVideoPlayer = nil
        isVideoReady = false
        videoPlayerCancellables.removeAll()
    }
    
    func playSharedVideo() {
        sharedVideoPlayer?.play()
    }
    
    func pauseSharedVideo() {
        sharedVideoPlayer?.pause()
    }
    
    // MARK: - Playlist Management
    
    func loadPlaylist(_ newItems: [PlaylistItem]) {
        pause()
        items = newItems
        currentIndex = 0
        resetItemProgress()
    }
    
    func addItem(_ item: PlaylistItem) {
        items.append(item)
        savePlaylistToDisk()
    }
    
    func removeItem(at index: Int) {
        guard index >= 0, index < items.count else { return }
        
        items.remove(at: index)
        
        if currentIndex >= items.count {
            currentIndex = max(0, items.count - 1)
        }
        
        savePlaylistToDisk()
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        savePlaylistToDisk()
    }
    
    func updateItemName(at index: Int, name: String) {
        guard index >= 0, index < items.count else { return }
        items[index].name = name
        savePlaylistToDisk()
    }
    
    func updateItemDuration(at index: Int, duration: TimeInterval) {
        guard index >= 0, index < items.count else { return }
        items[index].duration = duration
        savePlaylistToDisk()
    }
    
    func clearPlaylist() {
        pause()
        cleanupSharedVideoPlayer()
        items.removeAll()
        currentIndex = 0
        resetItemProgress()
        savePlaylistToDisk()
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        stopTimer()
        
        timer = Timer.publish(every: timerInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateProgress()
            }
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    private func updateProgress() {
        guard isPlaying, let startTime = itemStartTime else { return }
        
        // Skip timer-based progress for videos (they use AVPlayer time observer)
        if let item = currentItem, item.contentType.hasFixedDuration {
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        if currentItemDuration > 0 {
            currentProgress = min(elapsed / currentItemDuration, 1.0)
            timeRemaining = max(currentItemDuration - elapsed, 0)
            
            if elapsed >= currentItemDuration {
                next()
            }
        }
    }
    
    private func resetItemProgress() {
        currentProgress = 0
        if let item = currentItem {
            currentItemDuration = item.contentType.hasFixedDuration ? 0 : item.duration
            timeRemaining = currentItemDuration
        }
        itemStartTime = Date()
    }
    
    // MARK: - Persistence
    
    func savePlaylist() {
        savePlaylistToDisk()
    }
    
    func savePlaylistToDisk() {
        guard let playlist = currentPlaylist else { return }
        
        // Update playlist with current items and crawl data
        var updatedPlaylist = playlist
        updatedPlaylist.items = items
        updatedPlaylist.crawlData = crawlData  // CRAWL REVISION: Save crawl data
        updatedPlaylist.modifiedAt = Date()
        
        Task {
            try? await PlaylistStorageManager.shared.save(updatedPlaylist)
        }
    }
    
    func loadPlaylistFromDisk() {
        guard let playlist = currentPlaylist else {
            return
        }
        
        // Reset state for any playlist switch
        pause()
        cleanupSharedVideoPlayer()
        
        guard let playlistFileURL = PlaylistStorageManager.shared.playlistFileURL(for: playlist),
              FileManager.default.fileExists(atPath: playlistFileURL.path) else {
            // New playlist with no saved file - clear everything
            items = []
            crawlData = CrawlData()
            currentIndex = 0
            resetItemProgress()
            return
        }
        
        do {
            let data = try Data(contentsOf: playlistFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedPlaylist = try decoder.decode(Playlist.self, from: data)
            
            // Always load items (even if empty)
            items = loadedPlaylist.items
            currentIndex = 0
            resetItemProgress()
            
            // Load crawl data (or reset if none)
            crawlData = loadedPlaylist.crawlData ?? CrawlData()
        } catch {
            print("Failed to load playlist: \(error)")
            // On error, clear to empty state
            items = []
            crawlData = CrawlData()
            currentIndex = 0
            resetItemProgress()
        }
    }
    
    // MARK: - Web Content Snapshot Helpers
    
    /// Check if a content type uses WKWebView (anything except image/video)
    static func isWebBased(_ contentType: ContentType) -> Bool {
        switch contentType {
        case .image, .video:
            return false
        default:
            return true
        }
    }
    
    /// Capture the on-screen WKWebView as a UIImage for use as the outgoing transition curtain.
    /// Searches from the registered content view upward, then falls back to searching the window.
    private static func captureViewSnapshot(_ registeredView: UIView?, forExternal: Bool) -> UIImage? {
        var webView: WKWebView? = nil
        
        // Strategy 1: Walk UP from the registered view, searching each ancestor's subtree
        if let rv = registeredView {
            var ancestor: UIView? = rv
            while let a = ancestor, webView == nil {
                webView = findFirstWKWebView(in: a)
                ancestor = a.superview
            }
        }
        
        // Strategy 2: Search from the appropriate window
        if webView == nil {
            let targetWindow: UIWindow?
            if forExternal {
                targetWindow = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first { $0.screen != UIScreen.main && !$0.isHidden }
            } else {
                targetWindow = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first { $0.isKeyWindow }
            }
            if let window = targetWindow {
                webView = findFirstWKWebView(in: window)
            }
        }
        
        guard let wv = webView,
              wv.bounds.width > 0,
              wv.bounds.height > 0 else {
            return nil
        }
        
        let renderer = UIGraphicsImageRenderer(bounds: wv.bounds)
        return renderer.image { _ in
            wv.drawHierarchy(in: wv.bounds, afterScreenUpdates: false)
        }
    }
    
    /// Recursively find the first WKWebView in a view hierarchy
    private static func findFirstWKWebView(in view: UIView) -> WKWebView? {
        if let wv = view as? WKWebView { return wv }
        for sub in view.subviews {
            if let found = findFirstWKWebView(in: sub) { return found }
        }
        return nil
    }
    
    /// Capture the full content container (used for video snapshots where we want the whole view, not a specific WKWebView).
    /// Walks up from the registered ContentViewCapture to find the content ZStack and snapshots it.
    private static func captureContentSnapshot(_ registeredView: UIView?, forExternal: Bool) -> UIImage? {
        // The ContentViewCapture lives inside the current-item ZStack.
        // Walk up 2 levels to reach the ZStack that holds the content.
        guard let rv = registeredView,
              let container = rv.superview,
              container.bounds.width > 0,
              container.bounds.height > 0 else {
            return nil
        }
        
        let renderer = UIGraphicsImageRenderer(bounds: container.bounds)
        return renderer.image { _ in
            container.drawHierarchy(in: container.bounds, afterScreenUpdates: false)
        }
    }
    
    /// Extract the current video frame directly from an AVPlayer using AVAssetImageGenerator.
    /// This bypasses the AVPlayerLayer GPU path that drawHierarchy can't capture.
    private static func captureCurrentVideoFrame(from player: AVPlayer?) -> UIImage? {
        guard let player = player,
              let currentItem = player.currentItem else {
            return nil
        }
        
        let currentTime = currentItem.currentTime()
        guard currentTime.isValid, currentTime.seconds >= 0 else {
            return nil
        }
        
        let generator = AVAssetImageGenerator(asset: currentItem.asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        do {
            let cgImage = try generator.copyCGImage(at: currentTime, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("⚠️ Failed to capture video frame: \(error)")
            return nil
        }
    }
}

// MARK: - Playlist Model Extension

// CRAWL REVISION: Add crawlData to Playlist model
// You'll need to add this property to your Playlist struct:
//
// struct Playlist: Codable, Identifiable {
//     ...
//     var crawlData: CrawlData?  // <- Add this
//     ...
// }
