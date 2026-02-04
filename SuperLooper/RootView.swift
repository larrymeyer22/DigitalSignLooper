//
//  RootView.swift
//  Super Looper
//

import SwiftUI

struct RootView: View {
    @State private var selectedPlaylist: Playlist?
    
    var body: some View {
        Group {
            if let playlist = selectedPlaylist {
                ContentView(playlist: playlist, onExit: { selectedPlaylist = nil })
            } else {
                StartupView(selectedPlaylist: $selectedPlaylist)
            }
        }
    }
}
