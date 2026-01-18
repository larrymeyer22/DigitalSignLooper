//
//  VideoContentView.swift
//  Super Looper
//
//  Displays videos on iPad using the shared AVPlayer
//

import SwiftUI
import AVKit
import Combine

struct VideoContentView: View {
    let filename: String
    @ObservedObject var playlistManager: PlaylistManager
    
    var body: some View {
        ZStack {
            Color.black
            
            if let player = playlistManager.sharedVideoPlayer {
                VideoPlayer(player: player)
                    .disabled(true)
            } else if !playlistManager.isVideoReady {
                // Don't show loading spinner - just black for seamless look
                Color.black
            } else {
                errorView
            }
        }
        .onAppear {
            setupPlayerIfNeeded()
        }
        .onChange(of: filename) {
            setupPlayerIfNeeded()
        }
        .onChange(of: playlistManager.isPlaying) { _, isPlaying in
            if isPlaying {
                playlistManager.playSharedVideo()
            } else {
                playlistManager.pauseSharedVideo()
            }
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Unable to load video")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(filename)
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
    }
    
    private func setupPlayerIfNeeded() {
        // Only setup if we don't already have a ready player
        // (might have been preloaded during transition)
        if playlistManager.sharedVideoPlayer == nil || !playlistManager.isVideoReady {
            playlistManager.setupSharedVideoPlayer(for: filename)
        }
    }
}

// MARK: - Preview

#Preview {
    VideoContentView(
        filename: "sample.mp4",
        playlistManager: PlaylistManager(items: [])
    )
}
