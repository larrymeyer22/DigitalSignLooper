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
    @ObservedObject private var brandManager = BrandSettingsManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            // Transition animation helpers
            let transType = playlistManager.activeTransitionType
            let transDur = playlistManager.transitionDuration
            let isT = playlistManager.isTransitioning
            let hasPrev = playlistManager.previousItem != nil
            let w = geometry.size.width
            
            let prevOpacity: Double = {
                guard isT else { return 1.0 }
                switch transType {
                case .pushLeft, .pushRight: return 1.0
                default: return 0.0
                }
            }()
            let prevOffsetX: CGFloat = {
                guard isT else { return 0 }
                switch transType {
                case .pushLeft: return -w
                case .pushRight: return w
                default: return 0
                }
            }()
            let currOffsetX: CGFloat = {
                guard hasPrev else { return 0 }
                switch transType {
                case .pushLeft: return isT ? 0 : w
                case .pushRight: return isT ? 0 : -w
                default: return 0
                }
            }()
            let transAnimation: Animation = {
                switch transType {
                case .cut: return .linear(duration: 0)
                case .pushLeft, .pushRight: return .easeInOut(duration: transDur)
                default: return .linear(duration: transDur)
                }
            }()
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Current item (underneath) — loads in background, slides in for push
                if let item = playlistManager.currentItem {
                    ZStack {
                        contentView(for: item, size: geometry.size, isOutgoing: false)
                        ContentViewCapture(playlistManager: playlistManager, isExternal: true)
                    }
                    .id("ext-current-\(item.id)")
                    .offset(x: currOffsetX)
                    .animation(transAnimation, value: playlistManager.isTransitioning)
                }
                
                // Previous item (on top) — curtain: fades for dissolve, slides for push, snaps for cut
                if let previous = playlistManager.previousItem {
                    contentView(for: previous, size: geometry.size, isOutgoing: true)
                        .id("ext-previous-\(previous.id)")
                        .opacity(prevOpacity)
                        .offset(x: prevOffsetX)
                        .animation(transAnimation, value: playlistManager.isTransitioning)
                }
                
                // Waiting view only when no content at all
                if playlistManager.currentItem == nil && playlistManager.previousItem == nil {
                    waitingView
                }
                
                // CRAWL OVERLAY - positioned at bottom of video area
                if playlistManager.shouldShowCrawl {
                    VStack {
                        Spacer()
                        CrawlView(
                            data: playlistManager.crawlData,
                            brandSettings: brandManager.settings,
                            containerHeight: geometry.size.height
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func contentView(for item: PlaylistItem, size: CGSize, isOutgoing: Bool) -> some View {
        // For outgoing web content, use a pre-captured snapshot instead of
        // creating a new WKWebView (which causes a flash while it loads)
        if isOutgoing,
           let snapshot = playlistManager.outgoingWebSnapshotExternal,
           PlaylistManager.isWebBased(item.contentType) {
            ZStack {
                Color.black
                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            }
            .ignoresSafeArea()
        } else {
            standardContentView(for: item, size: size, isOutgoing: isOutgoing)
        }
    }
    
    @ViewBuilder
    private func standardContentView(for item: PlaylistItem, size: CGSize, isOutgoing: Bool) -> some View {
        switch item.contentType {
        case .image(let filename):
            if isOutgoing {
                ExternalImageDisplay(
                    filename: filename,
                    size: size,
                    preloadedImage: playlistManager.outgoingImage
                )
            } else {
                ExternalImageDisplay(
                    filename: filename, 
                    size: size,
                    preloadedImage: playlistManager.preloadedImageFilename == filename ? playlistManager.preloadedImage : nil
                )
            }
            
        case .video(_):
            // Use outgoing snapshot for instant-render curtain, fall back to live player
            if isOutgoing {
                if let snapshot = playlistManager.outgoingVideoSnapshotExternal {
                    ZStack {
                        Color.black
                        Image(uiImage: snapshot)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size.width, height: size.height)
                    }
                    .ignoresSafeArea()
                } else {
                    ExternalVideoDisplay(player: playlistManager.outgoingVideoPlayer)
                }
            } else {
                ExternalVideoDisplay(player: playlistManager.sharedVideoPlayer)
            }
            
        case .html(let content):
            HTMLContentView(htmlContent: content)
                .ignoresSafeArea()
            
        case .web(let url):
            // Render at 16:9 iPad-equivalent viewport, scale to fill TV
            let refWidth: CGFloat = 1280
            let refHeight: CGFloat = 720
            let scale = size.width / refWidth
            
            WebContentView(url: url)
                .frame(width: refWidth, height: refHeight)
                .scaleEffect(scale)
                .ignoresSafeArea()
            
        case .titleSlide(let data):
            TemplateHTMLView(html: TitleSlideRenderer.render(data: data, brandSettings: brandManager.settings))
                .id("titleSlide-\(brandManager.settings.settingsHash)")
                .ignoresSafeArea()
            
        case .featuredPerson(let data):
            FeaturedPersonTemplateView(data: data, brandSettings: brandManager.settings)
                .id("featuredPerson-\(brandManager.settings.settingsHash)")
                .ignoresSafeArea()
            
        case .schedule(let data):
            TemplateHTMLView(html: ScheduleRenderer.render(data: data, brandSettings: brandManager.settings))
                .id("schedule-\(brandManager.settings.settingsHash)")
                .ignoresSafeArea()
            
        case .leaderboard(let data):
            TemplateHTMLView(html: LeaderboardRenderer.render(data: data, brandSettings: brandManager.settings))
                .id("leaderboard-\(brandManager.settings.settingsHash)")
                .ignoresSafeArea()
            
        case .countdown(let data):
            TemplateHTMLView(html: CountdownRenderer.render(data: data, brandSettings: brandManager.settings))
                .id("countdown-\(brandManager.settings.settingsHash)-\(data.mode)")
                .ignoresSafeArea()
            
        case .weather(let data):
            WeatherContentView(data: data, brandSettings: brandManager.settings)
                .id("weather-\(data.latitude)-\(data.longitude)-\(brandManager.settings.settingsHash)")
                .ignoresSafeArea()
            
        case .liveWeb(let url, _):
            // Render at 16:9 iPad-equivalent viewport, scale to fill TV
            let refWidth: CGFloat = 1280
            let refHeight: CGFloat = 720
            let scale = size.width / refWidth
            
            WebContentView(url: url)
                .frame(width: refWidth, height: refHeight)
                .scaleEffect(scale)
                .ignoresSafeArea()
            
        case .customHTML(let filename):
            CustomHTMLFileView(filename: filename)
                .ignoresSafeArea()
        }
    }
    
    private var waitingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 120))
                .foregroundColor(.gray.opacity(0.2))
            
            Text("DigitalSignLooper")
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
        
        let playlistManager = SharedPlaylistManager.shared.manager
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = playlistManager.loadImage(filename: filename)
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

// MARK: - Custom HTML File View

struct CustomHTMLFileView: View {
    let filename: String
    @State private var htmlContent: String = ""
    
    var body: some View {
        HTMLContentView(htmlContent: htmlContent)
            .onAppear { loadHTML() }
            .onChange(of: filename) { _, _ in loadHTML() }
    }
    
    private func loadHTML() {
        // Try playlist's media folder first (via shared playlist manager)
        let playlistManager = SharedPlaylistManager.shared.manager
        if let playlistMediaFolder = playlistManager.mediaFolderURL {
            let playlistURL = playlistMediaFolder.appendingPathComponent(filename)
            if let content = try? String(contentsOf: playlistURL, encoding: .utf8) {
                htmlContent = content
                return
            }
        }
        
        // Fallback to global media folder (for backwards compatibility)
        if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docsURL.appendingPathComponent("SuperLooper/media/\(filename)")
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                htmlContent = content
                return
            }
        }
        
        htmlContent = "<html><body style='background:#000;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;'><h1>HTML file not found</h1></body></html>"
    }
}

// MARK: - Template HTML View

struct TemplateHTMLView: View {
    let html: String
    
    var body: some View {
        HTMLContentView(htmlContent: html)
    }
}

// MARK: - Weather Content View

struct WeatherContentView: View {
    let data: WeatherData
    let brandSettings: BrandSettings
    
    @State private var fetchedWeather: FetchedWeather?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let weather = fetchedWeather {
                TemplateHTMLView(html: WeatherRenderer.render(
                    data: data,
                    weather: weather,
                    brandSettings: brandSettings
                ))
            } else {
                TemplateHTMLView(html: WeatherRenderer.renderLoading(
                    data: data,
                    brandSettings: brandSettings
                ))
            }
        }
        .task {
            await loadWeather()
        }
    }
    
    private func loadWeather() async {
        // Check cache first
        if let cached = WeatherFetcher.shared.getCached(
            latitude: data.latitude,
            longitude: data.longitude
        ) {
            fetchedWeather = cached
            isLoading = false
            return
        }
        
        // Fetch fresh data
        if let weather = await WeatherFetcher.shared.fetchWeather(
            latitude: data.latitude,
            longitude: data.longitude,
            days: data.forecastDays
        ) {
            fetchedWeather = weather
            isLoading = false
        }
    }
}

// MARK: - Title Slide Renderer

enum TitleSlideRenderer {
    static func render(data: TitleSlideData, brandSettings: BrandSettings) -> String {
        let bgColor: String
        let textColor: String
        
        if data.usesBrandColors {
            bgColor = brandSettings.backgroundColor
            textColor = brandSettings.textColor
        } else {
            bgColor = data.customBackgroundColor ?? brandSettings.backgroundColor
            textColor = data.customTextColor ?? brandSettings.textColor
        }
        
        let titleFont = brandSettings.titleFontCSS
        let bodyFont = brandSettings.bodyFontCSS
        let titleWeight = brandSettings.titleFontWeight.cssValue
        let bodyWeight = brandSettings.bodyFontWeight.cssValue
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background: \(bgColor);
                    color: \(textColor);
                    font-family: \(bodyFont);
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    padding: 5%;
                    text-align: center;
                }
                h1 {
                    font-family: \(titleFont);
                    font-size: 8vw;
                    font-weight: \(titleWeight);
                    margin-bottom: 2vh;
                    line-height: 1.1;
                }
                h2 {
                    font-family: \(titleFont);
                    font-size: 4vw;
                    font-weight: \(bodyWeight);
                    opacity: 0.8;
                    margin-bottom: 2vh;
                }
                p {
                    font-family: \(bodyFont);
                    font-size: 2.5vw;
                    font-weight: \(bodyWeight);
                    opacity: 0.7;
                    max-width: 80%;
                    line-height: 1.4;
                }
            </style>
        </head>
        <body>
            <h1>\(escapeHTML(data.headline))</h1>
        """
        
        if let subheadline = data.subheadline, !subheadline.isEmpty {
            html += "<h2>\(escapeHTML(subheadline))</h2>"
        }
        
        if let bodyText = data.bodyText, !bodyText.isEmpty {
            html += "<p>\(escapeHTML(bodyText))</p>"
        }
        
        html += "</body></html>"
        return html
    }
    
    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - Featured Person Renderer

enum FeaturedPersonRenderer {
    static func render(data: FeaturedPersonData, brandSettings: BrandSettings, photoBase64: String? = nil) -> String {
        let bgColor = data.usesBrandColors ? brandSettings.backgroundColor : (data.customBackgroundColor ?? brandSettings.backgroundColor)
        let textColor = data.usesBrandColors ? brandSettings.textColor : (data.customTextColor ?? brandSettings.textColor)
        let accentColor = data.usesBrandColors ? brandSettings.accentColor : (data.customAccentColor ?? brandSettings.accentColor)
        
        let titleFont = brandSettings.titleFontCSS
        let bodyFont = brandSettings.bodyFontCSS
        let titleWeight = brandSettings.titleFontWeight.cssValue
        
        // Photo HTML - either base64 image or placeholder
        let photoContent: String
        if let base64 = photoBase64 {
            photoContent = """
            <img src="data:image/jpeg;base64,\(base64)" alt="\(escapeHTML(data.name))" class="photo-img">
            """
        } else {
            photoContent = """
            <div class="photo-placeholder">👤</div>
            """
        }
        
        // Optional subtitle
        let subtitleHTML = data.subtitle.map { """
            <div class="subtitle">\(escapeHTML($0))</div>
        """ } ?? ""
        
        // Feature title (e.g., "Employee of the Week")
        let featureTitleHTML = data.featureTitle.map { """
            <div class="award">\(escapeHTML($0))</div>
        """ } ?? ""
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background: \(bgColor);
                    color: \(textColor);
                    font-family: \(bodyFont);
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    padding: 5%;
                    text-align: center;
                }
                .award {
                    font-family: \(titleFont);
                    font-size: 3vw;
                    color: \(accentColor);
                    text-transform: uppercase;
                    letter-spacing: 0.3em;
                    margin-bottom: 4vh;
                    font-weight: \(titleWeight);
                }
                .photo-container {
                    width: 28vw;
                    height: 28vw;
                    max-width: 400px;
                    max-height: 400px;
                    margin-bottom: 4vh;
                    border-radius: 12%;
                    overflow: hidden;
                    background: rgba(255,255,255,0.1);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .photo-img {
                    width: 100%;
                    height: 100%;
                    object-fit: cover;
                }
                .photo-placeholder {
                    font-size: 12vw;
                    opacity: 0.5;
                }
                .name {
                    font-family: \(titleFont);
                    font-size: 5vw;
                    font-weight: \(titleWeight);
                    margin-bottom: 1.5vh;
                }
                .title {
                    font-family: \(bodyFont);
                    font-size: 2.5vw;
                    opacity: 0.8;
                }
                .subtitle {
                    font-family: \(bodyFont);
                    font-size: 2vw;
                    opacity: 0.6;
                    margin-top: 1vh;
                }
            </style>
        </head>
        <body>
            \(featureTitleHTML)
            <div class="photo-container">
                \(photoContent)
            </div>
            <div class="name">\(escapeHTML(data.name))</div>
            <div class="title">\(escapeHTML(data.title))</div>
            \(subtitleHTML)
        </body>
        </html>
        """
    }
    
    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - Featured Person Template View

struct FeaturedPersonTemplateView: View {
    let data: FeaturedPersonData
    let brandSettings: BrandSettings
    
    @State private var photoBase64: String?
    
    var body: some View {
        let bgHex = data.usesBrandColors ? brandSettings.backgroundColor : (data.customBackgroundColor ?? brandSettings.backgroundColor)
        
        ZStack {
            Color(hex: bgHex)
            HTMLContentView(htmlContent: FeaturedPersonRenderer.render(
                data: data,
                brandSettings: brandSettings,
                photoBase64: photoBase64
            ))
        }
        .onAppear {
            loadPhoto()
        }
    }
    
    private func loadPhoto() {
        guard let filename = data.photoFilename else { return }
        
        let playlistManager = SharedPlaylistManager.shared.manager
        Task { @MainActor in
            if let image = playlistManager.loadImage(filename: filename),
               let jpegData = image.jpegData(compressionQuality: 0.8) {
                let base64 = jpegData.base64EncodedString()
                self.photoBase64 = base64
            }
        }
    }
}

// MARK: - Color Hex Extension

fileprivate extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Schedule Renderer

enum ScheduleRenderer {
    static func render(data: ScheduleData, brandSettings: BrandSettings) -> String {
        let bgColor = data.usesBrandColors ? brandSettings.backgroundColor : (data.customBackgroundColor ?? brandSettings.backgroundColor)
        let textColor = data.usesBrandColors ? brandSettings.textColor : (data.customTextColor ?? brandSettings.textColor)
        let accentColor = data.usesBrandColors ? brandSettings.accentColor : (data.customAccentColor ?? brandSettings.accentColor)
        
        let titleFont = brandSettings.titleFontCSS
        let bodyFont = brandSettings.bodyFontCSS
        let titleWeight = brandSettings.titleFontWeight.cssValue
        
        // Parse settings from subtitle (format: "{seconds,alignment}")
        var secondsPerEvent = 8
        var alignmentCSS = "center"
        if let subtitle = data.subtitle, subtitle.hasPrefix("{") {
            let trimmed = subtitle.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
            let parts = trimmed.split(separator: ",")
            if parts.count >= 1, let secs = Int(parts[0]) {
                secondsPerEvent = secs
            }
            if parts.count >= 2 {
                alignmentCSS = String(parts[1]) == "left" ? "flex-start" : "center"
            }
        }
        
        let totalDuration = secondsPerEvent * data.events.count
        
        // Build events HTML and CSS animations
        var eventsHTML = ""
        var keyframesCSS = ""
        
        for (index, event) in data.events.enumerated() {
            let day = event.description ?? "" // Day stored in description field
            let presenter = event.speaker ?? ""
            let location = event.location ?? ""
            
            eventsHTML += """
            <div class="event event-\(index)">
                <div class="title">\(escapeHTML(event.title))</div>
                \(presenter.isEmpty ? "" : "<div class=\"presenter\">\(escapeHTML(presenter))</div>")
                <div class="details">
                    \(event.time.isEmpty ? "" : "<div class=\"time\">\(escapeHTML(event.time.uppercased()))</div>")
                    \(day.isEmpty ? "" : "<div class=\"day\">\(escapeHTML(day.uppercased()))</div>")
                    \(location.isEmpty ? "" : "<div class=\"location\">\(escapeHTML(location.uppercased()))</div>")
                </div>
            </div>
            """
            
            // Calculate animation timing for this event
            let startPercent = Double(index) / Double(data.events.count) * 100
            let endPercent = Double(index + 1) / Double(data.events.count) * 100
            let fadeInEnd = startPercent + 2
            let fadeOutStart = endPercent - 2
            
            keyframesCSS += """
            @keyframes event\(index) {
                0%, \(String(format: "%.1f", startPercent))% { opacity: 0; transform: scale(0.95); }
                \(String(format: "%.1f", fadeInEnd))%, \(String(format: "%.1f", fadeOutStart))% { opacity: 1; transform: scale(1); }
                \(String(format: "%.1f", endPercent))%, 100% { opacity: 0; transform: scale(0.95); }
            }
            .event-\(index) { animation: event\(index) \(totalDuration)s infinite; }
            """
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                
                body {
                    background: \(bgColor);
                    color: \(textColor);
                    font-family: \(bodyFont);
                    height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    overflow: hidden;
                }
                
                .container {
                    position: relative;
                    width: 100%;
                    height: 100%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                
                .event {
                    position: absolute;
                    width: 100%;
                    padding: 8%;
                    display: flex;
                    flex-direction: column;
                    align-items: \(alignmentCSS);
                    justify-content: center;
                    text-align: \(alignmentCSS == "center" ? "center" : "left");
                    opacity: 0;
                }
                
                .title {
                    font-family: \(titleFont);
                    font-size: 5vw;
                    font-weight: \(titleWeight);
                    line-height: 1.2;
                    margin-bottom: 1.5vh;
                }
                
                .presenter {
                    font-family: \(bodyFont);
                    font-size: 3vw;
                    font-weight: 400;
                    opacity: 0.9;
                    margin-bottom: 4vh;
                }
                
                .details {
                    display: flex;
                    flex-direction: column;
                    gap: 1vh;
                    align-items: \(alignmentCSS);
                }
                
                .time {
                    font-size: 2.2vw;
                    font-weight: 600;
                    letter-spacing: 0.15em;
                    color: \(accentColor);
                }
                
                .day {
                    font-size: 1.8vw;
                    font-weight: 500;
                    letter-spacing: 0.15em;
                    opacity: 0.7;
                }
                
                .location {
                    font-size: 1.8vw;
                    font-weight: 500;
                    letter-spacing: 0.15em;
                    opacity: 0.6;
                }
                
                \(keyframesCSS)
            </style>
        </head>
        <body>
            <div class="container">
                \(eventsHTML)
            </div>
        </body>
        </html>
        """
    }
    
    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
