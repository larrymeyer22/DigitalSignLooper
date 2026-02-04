//
//  SharedPlaylistManager.swift
//  Super Looper
//
//  Singleton to share PlaylistManager between ContentView and ExternalDisplayManager
//

import Foundation

@MainActor
class SharedPlaylistManager {
    static let shared = SharedPlaylistManager()
    
    let manager: PlaylistManager
    
    private init() {
        manager = PlaylistManager()
    }
}
