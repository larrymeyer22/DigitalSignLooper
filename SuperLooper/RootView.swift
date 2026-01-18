//
//  RootView.swift
//  Super Looper
//
//  Root view that manages navigation between startup and main content
//

import SwiftUI

struct RootView: View {
    @State private var selectedPlaylist: PlaylistInfo?
    var libraryManager = PlaylistLibraryManager.shared
    
    var body: some View {
        Group {
            if let playlist = selectedPlaylist {
                ContentView(
                    playlist: playlist,
                    onExit: { selectedPlaylist = nil }
                )
            } else {
                StartupView(selectedPlaylist: $selectedPlaylist)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedPlaylist?.id)
    }
}

#Preview {
    RootView()
}
