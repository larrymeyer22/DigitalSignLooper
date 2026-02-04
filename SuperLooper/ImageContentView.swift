//
//  ImageContentView.swift
//  Super Looper
//
//  Displays images from the playlist's media folder
//

import SwiftUI

struct ImageContentView: View {
    let filename: String
    var preloadedImage: UIImage? = nil
    
    @ObservedObject private var playlistManager = SharedPlaylistManager.shared.manager
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                } else if isLoading {
                    // Don't show loading indicator - just black to avoid flash
                    Color.black
                } else if loadError {
                    errorView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: filename) {
            loadImage()
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Unable to load image")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(filename)
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
    }
    
    private func loadImage() {
        // Use preloaded image if available
        if let preloaded = preloadedImage {
            image = preloaded
            isLoading = false
            return
        }
        
        isLoading = true
        loadError = false
        
        // Load using PlaylistManager (checks playlist media folder first)
        Task {
            let loadedImage = playlistManager.loadImage(filename: filename)
            
            await MainActor.run {
                isLoading = false
                if let loadedImage = loadedImage {
                    image = loadedImage
                } else {
                    // Try loading from bundle (for sample/demo content)
                    if let bundleImage = UIImage(named: filename.replacingOccurrences(of: ".jpg", with: "").replacingOccurrences(of: ".png", with: "")) {
                        image = bundleImage
                    } else {
                        loadError = true
                        print("❌ Failed to load image: \(filename)")
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ImageContentView(filename: "sample.jpg")
        .background(Color.black)
}
