//
//  ExternalDisplayManager.swift
//  SuperLooper
//
//  Manages external display detection and content window
//

import UIKit
import SwiftUI
import Combine
import AVKit

@MainActor
class ExternalDisplayManager: ObservableObject {
    static let shared = ExternalDisplayManager()
    
    @Published var isConnected = false
    
    private var externalWindow: UIWindow?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
        // Check on next run loop to allow app to fully initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkForExternalDisplay()
        }
    }
    
    private func setupNotifications() {
        // Monitor for screen connections using NotificationCenter
        NotificationCenter.default.publisher(for: UIScreen.didConnectNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                print("🖥️ Screen connected")
                if let screen = notification.object as? UIScreen {
                    self?.handleScreenConnect(screen)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIScreen.didDisconnectNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🖥️ Screen disconnected")
                self?.handleScreenDisconnect()
            }
            .store(in: &cancellables)
    }
    
    func checkForExternalDisplay() {
        let screens = UIScreen.screens
        print("🖥️ Checking screens: \(screens.count) found")
        
        if screens.count > 1, let externalScreen = screens.last {
            handleScreenConnect(externalScreen)
        }
    }
    
    private func handleScreenConnect(_ screen: UIScreen) {
        guard externalWindow == nil else { 
            print("🖥️ External window already exists")
            return 
        }
        
        print("🖥️ Setting up external window on screen: \(screen.bounds)")
        
        // Find or create window scene for this screen
        let matchingScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.screen == screen }
        
        let window: UIWindow
        if let scene = matchingScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: screen.bounds)
        }
        
        window.backgroundColor = .black
        
        // Create external content view using shared playlist manager
        let playlistManager = SharedPlaylistManager.shared.manager
        let externalView = ExternalScreenView(playlistManager: playlistManager)
        let hostingController = UIHostingController(rootView: externalView)
        hostingController.view.backgroundColor = .black
        
        window.rootViewController = hostingController
        window.isHidden = false
        
        externalWindow = window
        isConnected = true
        
        print("✅ External window ready")
    }
    
    private func handleScreenDisconnect() {
        externalWindow?.isHidden = true
        externalWindow = nil
        isConnected = false
        print("❌ External window removed")
    }
}

// MARK: - External Screen View (TV - clean, no controls, seamless crossfade)

struct ExternalScreenView: View {
    @ObservedObject var playlistManager: PlaylistManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Previous item (fading OUT during transition)
                if let previous = playlistManager.previousItem {
                    contentView(for: previous, size: geometry.size, isOutgoing: true)
                        .id("ext-previous-\(previous.id)")
                        .opacity(playlistManager.isTransitioning ? 0 : 1)
                        .animation(.linear(duration: playlistManager.transitionDuration), value: playlistManager.isTransitioning)
                }
                
                // Current item (fading IN during transition)  
                if let item = playlistManager.currentItem {
                    contentView(for: item, size: geometry.size, isOutgoing: false)
                        .id("ext-current-\(item.id)")
                        .animation(.linear(duration: playlistManager.transitionDuration), value: item.id)
                }
                
                // Waiting view only when no content at all
                if playlistManager.currentItem == nil && playlistManager.previousItem == nil {
                    waitingView
                }
            }
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func contentView(for item: PlaylistItem, size: CGSize, isOutgoing: Bool) -> some View {
        switch item.contentType {
        case .image(let filename):
            ExternalImageDisplay(
                filename: filename, 
                size: size,
                preloadedImage: playlistManager.preloadedImageFilename == filename ? playlistManager.preloadedImage : nil
            )
            
        case .video(_):
            // Use outgoing player for previous video, shared player for current
            if isOutgoing {
                ExternalVideoDisplay(player: playlistManager.outgoingVideoPlayer)
            } else {
                ExternalVideoDisplay(player: playlistManager.sharedVideoPlayer)
            }
            
        case .html(let content):
            HTMLContentView(htmlContent: content)
                .ignoresSafeArea()
            
        case .web(let url):
            WebContentView(url: url)
                .ignoresSafeArea()
        }
    }
    
    private var waitingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 120))
                .foregroundColor(.gray.opacity(0.2))
            
            Text("Super Looper")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.gray.opacity(0.2))
        }
    }
}

// MARK: - External Image Display

struct ExternalImageDisplay: View {
    let filename: String
    let size: CGSize
    var preloadedImage: UIImage? = nil
    
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            Color.black
            
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            }
        }
        .onAppear { loadImage() }
        .onChange(of: filename) { _, _ in loadImage() }
    }
    
    private func loadImage() {
        // Use preloaded image if available
        if let preloaded = preloadedImage {
            image = preloaded
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = FileSystemManager.shared.loadImage(filename: filename)
            DispatchQueue.main.async { 
                self.image = loaded 
            }
        }
    }
}

// MARK: - External Video Display (no controls, fills screen)

struct ExternalVideoDisplay: View {
    let player: AVPlayer?
    
    var body: some View {
        ZStack {
            Color.black
            
            if let player = player {
                AVPlayerControllerRepresentable(player: player)
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - AVPlayer Controller (no controls)

struct AVPlayerControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        controller.allowsPictureInPicturePlayback = false
        return controller
    }
    
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}
