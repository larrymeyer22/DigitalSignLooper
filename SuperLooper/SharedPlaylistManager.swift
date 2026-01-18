//
//  SharedPlaylistManager.swift
//  SuperLooper
//
//  Singleton to share PlaylistManager between iPad and external display
//

import Foundation

class SharedPlaylistManager {
    static let shared = SharedPlaylistManager()
    
    let manager: PlaylistManager
    
    private init() {
        self.manager = PlaylistManager(items: [])
    }
}
