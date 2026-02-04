//
//  SuperLooperApp.swift
//  SuperLooper
//
//  Created by Larry Meyer on 1/17/26.
//

import SwiftUI
import Combine

@main
struct SuperLooperApp: App {
    @StateObject private var airDropHandler = AirDropHandler.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .sheet(isPresented: $airDropHandler.showPlaylistPicker) {
                    AirDropPlaylistPicker(airDropHandler: airDropHandler)
                        .preferredColorScheme(ColorScheme.dark)
                }
                .alert("AirDrop Import", isPresented: .constant(airDropHandler.lastImportedCount > 0 && airDropHandler.lastImportError == nil)) {
                    Button("OK") {
                        airDropHandler.lastImportedCount = 0
                    }
                } message: {
                    Text("Successfully imported \(airDropHandler.lastImportedCount) file\(airDropHandler.lastImportedCount == 1 ? "" : "s") to the playlist.")
                }
                .alert("AirDrop Error", isPresented: .constant(airDropHandler.lastImportError != nil)) {
                    Button("OK") {
                        airDropHandler.lastImportError = nil
                    }
                } message: {
                    Text(airDropHandler.lastImportError ?? "")
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        Task { @MainActor in
            await airDropHandler.handleIncomingURLs([url])
        }
    }
}

