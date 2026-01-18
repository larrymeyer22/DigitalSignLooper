//
//  PlaylistManager.swift
//  Super Looper
//
//  Manages playlist playback state, timing, and transitions
//

import Foundation
import Combine
import SwiftUI
import AVFoundation

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
    @Published var isVideoReady: Bool = false
    @Published var previousItem: PlaylistItem?
    @Published var isTransitioning: Bool = false
    @Published var preloadedImage: UIImage?
    @Published var preloadedImageFilename: String?
    
    // MARK: - Private Properties
    
    private var preloadedVideoPlayer: AVPlayer?
    private var preloadedVideoFilename: String?
    private var timer: AnyCancellable?
    private var itemStartTime: Date?
    private var currentItemDuration: TimeInterval = 0
    private var videoPlayerCancellables = Set<AnyCancellable>()
    private var preloadedVideoPlayerCancellables = Set<AnyCancellable>()
    private var transitionWorkItem: DispatchWorkItem?
    private let timerInterval: TimeInterval = 0.1
    
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
                Task.detached { [weak self] in
                    let image = FileSystemManager.shared.loadImage(filename: filename)
                    await MainActor.run {
                        self?.preloadedImage = image
                        self?.preloadedImageFilename = filename
                    }
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
        let url = FileSystemManager.shared.videoURL(for: filename)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Video file not found for preload: \(url.path)")
            return
        }
        
        let asset = AVAsset(url: url)
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
            currentItemDuration = item.contentType.hasFixedDuration ? 0 : item.duration
            timeRemaining = currentItemDuration
        }
        
        startTimer()
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
    
    // MARK: - Crossfade Transition
    
    private func performTransition(indexChange: @escaping () -> Void) {
        transitionWorkItem?.cancel()
        
        let outgoingItem = currentItem
        previousItem = outgoingItem
        
        let outgoingIsVideo = outgoingItem?.contentType.isVideo ?? false
        
        if outgoingIsVideo {
            outgoingVideoPlayer = sharedVideoPlayer
            sharedVideoPlayer = nil
        }
        
        indexChange()
        
        var incomingIsVideo = false
        if let current = currentItem, case .video(let filename) = current.contentType {
            incomingIsVideo = true
            
            if preloadedVideoFilename == filename, let preloaded = preloadedVideoPlayer {
                sharedVideoPlayer = preloaded
                preloadedVideoPlayer = nil
                preloadedVideoFilename = nil
                
                videoPlayerCancellables = preloadedVideoPlayerCancellables
                preloadedVideoPlayerCancellables = Set<AnyCancellable>()
                
                setupTimeObserver(for: sharedVideoPlayer!)
                
                if let playerItem = sharedVideoPlayer?.currentItem {
                    Task {
                        do {
                            let duration = try await playerItem.asset.load(.duration)
                            let seconds = CMTimeGetSeconds(duration)
                            if seconds.isFinite && seconds > 0 {
                                await MainActor.run {
                                    self.setCurrentVideoDuration(seconds)
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
        
        // Delay crossfade to let incoming content render first frame
        let frameDelay: TimeInterval = incomingIsVideo ? 0.15 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + frameDelay) { [weak self] in
            guard let self = self else { return }
            self.isTransitioning = true
            self.preloadNextItem()
        }
        
        // Clear outgoing content after transition completes
        let totalDelay = transitionDuration + 0.2
        let workItem = DispatchWorkItem { [weak self] in
            self?.previousItem = nil
            self?.isTransitioning = false
            self?.outgoingVideoPlayer?.pause()
            self?.outgoingVideoPlayer = nil
        }
        transitionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay, execute: workItem)
    }
    
    private func setupTimeObserver(for player: AVPlayer) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self,
                      let item = self.currentItem,
                      item.contentType.hasFixedDuration,
                      self.currentItemDuration > 0 else { return }
                
                let currentTime = CMTimeGetSeconds(time)
                self.currentProgress = min(currentTime / self.currentItemDuration, 1.0)
                self.timeRemaining = max(self.currentItemDuration - currentTime, 0)
            }
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
        
        let url = FileSystemManager.shared.videoURL(for: filename)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Video file not found: \(url.path)")
            return
        }
        
        let asset = AVAsset(url: url)
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
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)
                if seconds.isFinite && seconds > 0 {
                    await MainActor.run {
                        self.setCurrentVideoDuration(seconds)
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
                player.preroll(atRate: 1.0) { success in
                    Task { @MainActor in
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(items)
            try data.write(to: FileSystemManager.shared.playlistFileURL)
        } catch {
            print("Failed to save playlist: \(error)")
        }
    }
    
    func loadPlaylistFromDisk() {
        let url = FileSystemManager.shared.playlistFileURL
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loadedItems = try decoder.decode([PlaylistItem].self, from: data)
            if !loadedItems.isEmpty {
                items = loadedItems
                currentIndex = 0
                resetItemProgress()
            }
        } catch {
            print("Failed to load playlist: \(error)")
        }
    }
}
