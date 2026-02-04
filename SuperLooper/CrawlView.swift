//
//  CrawlView.swift
//  Super Looper
//
//  Displays a continuous scrolling text crawl at the bottom of the video area
//  Uses Timer at fixed 30fps for consistent AirPlay performance
//

import SwiftUI

struct CrawlView: View {
    let data: CrawlData
    let brandSettings: BrandSettings?
    let containerHeight: CGFloat
    
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var currentOffset: CGFloat = 0
    @State private var timer: Timer?
    
    // Fixed 30fps for consistent performance over AirPlay
    private let frameInterval: TimeInterval = 1.0 / 30.0
    
    // MARK: - Responsive Sizing
    
    private var crawlHeight: CGFloat {
        let baseHeight = max(containerHeight * 0.07, 36)
        return baseHeight * data.size.multiplier
    }
    
    private var fontSize: CGFloat {
        crawlHeight * 0.5
    }
    
    private let separator = "   •   "
    
    private var backgroundColor: Color {
        data.backgroundStyle.color(brandSettings: brandSettings, customHex: data.customBackgroundColor)
    }
    
    /// Fixed cycle duration based ONLY on speed setting (same for all screens)
    private var cycleDuration: Double {
        switch data.speed {
        case .slow: return 20
        case .medium: return 12
        case .fast: return 7
        case .veryFast: return 4
        }
    }
    
    /// Total travel distance for the crawl
    private var totalTravel: CGFloat {
        containerWidth + textWidth
    }
    
    /// Pixels to move per frame at 30fps
    private var pixelsPerFrame: CGFloat {
        guard cycleDuration > 0 else { return 0 }
        let framesPerCycle = cycleDuration / frameInterval
        return totalTravel / CGFloat(framesPerCycle)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if data.isEnabled && data.hasContent {
                    backgroundColor
                    
                    crawlText
                        .background(
                            GeometryReader { textGeo in
                                Color.clear
                                    .onAppear {
                                        textWidth = textGeo.size.width
                                    }
                                    .onChange(of: textGeo.size.width) { _, newWidth in
                                        textWidth = newWidth
                                    }
                            }
                        )
                        .offset(x: currentOffset)
                }
            }
            .clipShape(Rectangle())
            .drawingGroup(opaque: true)
            .onAppear {
                containerWidth = geometry.size.width
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                containerWidth = newWidth
            }
            .onChange(of: data.isEnabled) { _, enabled in
                if enabled {
                    currentOffset = containerWidth
                    startTimer()
                } else {
                    stopTimer()
                }
            }
            .onChange(of: data.items) { _, _ in
                restartTimer()
            }
            .onChange(of: data.speed) { _, _ in
                restartTimer()
            }
            .onChange(of: data.size) { _, _ in
                restartTimer()
            }
        }
        .frame(height: crawlHeight)
    }
    
    private var crawlText: some View {
        Text(formattedText)
            .font(.system(size: fontSize, weight: .semibold, design: .default))
            .foregroundColor(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 20)
    }
    
    private var formattedText: String {
        data.items
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: separator)
    }
    
    // MARK: - Timer Control
    
    private func startTimer() {
        guard data.isEnabled && data.hasContent else { return }
        stopTimer()
        
        // Initialize position off-screen right
        currentOffset = containerWidth
        
        // Create timer on main run loop
        timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { _ in
            Task { @MainActor in
                updatePosition()
            }
        }
    }
    
    private func updatePosition() {
        guard totalTravel > 0 else { return }
        
        // Move left by fixed amount
        currentOffset -= pixelsPerFrame
        
        // Reset when fully off-screen left
        if currentOffset < -textWidth {
            currentOffset = containerWidth
        }
    }
    
    private func restartTimer() {
        stopTimer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startTimer()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        currentOffset = containerWidth
    }
}

// MARK: - Compact Crawl Control Pill

/// A small pill button for the control panel - tap to toggle, long-press to edit
struct CrawlControlPill: View {
    @Binding var crawlData: CrawlData
    @Binding var showCrawlEditor: Bool
    
    var body: some View {
        Button {
            // Quick toggle
            withAnimation(.easeInOut(duration: 0.2)) {
                crawlData.isEnabled.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.system(size: 14, weight: .medium))
                
                if crawlData.hasContent {
                    Circle()
                        .fill(crawlData.isEnabled ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .foregroundColor(crawlData.isEnabled ? .white : .white.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(crawlData.isEnabled ? Color.blue.opacity(0.8) : Color.white.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    showCrawlEditor = true
                }
        )
        .contextMenu {
            Button {
                crawlData.isEnabled.toggle()
            } label: {
                Label(
                    crawlData.isEnabled ? "Turn Off Crawl" : "Turn On Crawl",
                    systemImage: crawlData.isEnabled ? "stop.circle" : "play.circle"
                )
            }
            
            Divider()
            
            Button {
                showCrawlEditor = true
            } label: {
                Label("Edit Crawl...", systemImage: "pencil")
            }
        }
    }
}

// MARK: - Preview

#Preview("Crawl View") {
    ZStack {
        Color.blue.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            CrawlView(
                data: CrawlData(
                    items: [
                        "Welcome to the conference!",
                        "Lunch served at 12:00 PM",
                        "Keynote speaker at 2:00 PM",
                        "Visit booth #42 for prizes"
                    ],
                    speed: .medium,
                    backgroundStyle: .semitransparentDark,
                    isEnabled: true
                ),
                brandSettings: nil,
                containerHeight: 400
            )
        }
    }
}

#Preview("Crawl Pill") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        CrawlControlPill(
            crawlData: .constant(CrawlData(
                items: ["Test message"],
                isEnabled: true
            )),
            showCrawlEditor: .constant(false)
        )
    }
}
