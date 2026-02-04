//
//  ContentTemplatesView.swift
//  Super Looper
//
//  Gallery of content templates for quick creation
//
//  ⚠️ CRAWL REMOVED: Crawl is now accessed via the control panel pill,
//  not as a content template. See CrawlEditorSheet.swift
//

import SwiftUI
import WebKit

struct ContentTemplatesView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTemplate: TemplateType?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(TemplateType.allCases) { template in
                        TemplateCard(template: template) {
                            selectedTemplate = template
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Create Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                templateEditor(for: template)
                    .preferredColorScheme(.dark)
            }
        }
    }
    
    @ViewBuilder
    private func templateEditor(for template: TemplateType) -> some View {
        switch template {
        case .titleSlide:
            TitleSlideEditorView(playlistManager: playlistManager)
        case .featuredPerson:
            FeaturedPersonEditorView(playlistManager: playlistManager)
        case .schedule:
            ScheduleEditorView(playlistManager: playlistManager)
        case .leaderboard:
            LeaderboardEditorView(playlistManager: playlistManager)
        case .countdown:
            CountdownEditorView(playlistManager: playlistManager)
        // REMOVED: case .crawl - crawl is now a playlist-level setting
        case .liveWebsite:
            LiveWebsiteEditorView(playlistManager: playlistManager)
        case .customHTML:
            CustomHTMLEditorView(playlistManager: playlistManager)
        }
    }
}

// MARK: - Template Type

enum TemplateType: String, CaseIterable, Identifiable {
    case titleSlide = "Title Slide"
    case featuredPerson = "Featured Person"
    case schedule = "Schedule"
    case leaderboard = "Leaderboard"
    case countdown = "Countdown Timer"
    // REMOVED: case crawl = "Bottom Crawl" - now a playlist-level setting
    case liveWebsite = "Live Website"
    case customHTML = "Custom HTML"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .titleSlide: return "text.badge.star"
        case .featuredPerson: return "person.crop.circle.fill"
        case .schedule: return "calendar"
        case .leaderboard: return "trophy.fill"
        case .countdown: return "timer"
        case .liveWebsite: return "globe"
        case .customHTML: return "doc.text.fill"
        }
    }
    
    var description: String {
        switch self {
        case .titleSlide: return "Simple message display"
        case .featuredPerson: return "Employee of the month"
        case .schedule: return "Rotating event display"
        case .leaderboard: return "Top 10 rankings"
        case .countdown: return "Countdown to event"
        case .liveWebsite: return "Display a live URL"
        case .customHTML: return "Import your own HTML"
        }
    }
    
    var color: Color {
        switch self {
        case .titleSlide: return .blue
        case .featuredPerson: return .orange
        case .schedule: return .green
        case .leaderboard: return .yellow
        case .countdown: return .red
        case .liveWebsite: return .purple
        case .customHTML: return .gray
        }
    }
    
    var isAvailable: Bool {
        return true // All templates now available
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: TemplateType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(template.color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: template.icon)
                        .font(.title)
                        .foregroundColor(template.color)
                }
                
                // Title
                Text(template.rawValue)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Description
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Coming soon badge
                if !template.isAvailable {
                    Text("Coming Soon")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray)
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .opacity(template.isAvailable ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!template.isAvailable)
    }
}

// MARK: - Coming Soon Placeholder

struct ComingSoonView: View {
    let templateName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("\(templateName)")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Coming Soon")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("This template is still being built. Check back soon!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(templateName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Live Website Editor

struct LiveWebsiteEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    // Edit mode
    var editingIndex: Int?
    var existingURL: URL?
    
    @State private var urlString: String = ""
    @State private var itemName: String = ""
    @State private var duration: Double = 20
    @State private var preloadSeconds: Double = 3
    @State private var isValidURL: Bool = false
    @State private var transition: TransitionType = .dissolve
    @State private var transitionDuration: Double = 0.5
    
    // Test URL state
    @State private var showTestView: Bool = false
    @State private var testResult: URLTestResult?
    
    // Focus state
    @FocusState private var isURLFieldFocused: Bool
    
    private var isEditing: Bool { editingIndex != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com", text: $urlString)
                        .focused($isURLFieldFocused)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: urlString) { _, newValue in
                            isValidURL = URL(string: newValue)?.scheme?.hasPrefix("http") ?? false
                            testResult = nil // Reset test when URL changes
                        }
                    
                    if !urlString.isEmpty && !isValidURL {
                        Text("Enter a valid URL starting with http:// or https://")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    // Test URL button
                    if isValidURL {
                        Button {
                            showTestView = true
                        } label: {
                            HStack {
                                Image(systemName: "play.circle")
                                Text("Test URL")
                                Spacer()
                                if let result = testResult {
                                    testResultBadge(result)
                                }
                            }
                        }
                    }
                } header: {
                    Label("Website URL", systemImage: "globe")
                } footer: {
                    if let result = testResult {
                        Text(result.message)
                            .foregroundColor(result.isSuccess ? .green : .orange)
                    } else {
                        Text("Test the URL to check if it can be displayed")
                    }
                }
                
                Section {
                    TextField("Item name", text: $itemName)
                } header: {
                    Label("Name", systemImage: "tag")
                } footer: {
                    Text("How this item appears in your playlist")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Display Duration")
                            Spacer()
                            Text("\(Int(duration)) seconds")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $duration, in: 5...120, step: 5)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Preload Time")
                            Spacer()
                            Text("\(Int(preloadSeconds)) seconds")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $preloadSeconds, in: 1...10, step: 1)
                    }
                } header: {
                    Label("Timing", systemImage: "clock")
                } footer: {
                    Text("Preload time lets the page load before displaying for seamless transitions.")
                }
                
                // MARK: - Transition
                Section {
                    Picker("Style", selection: $transition) {
                        ForEach(TransitionType.availableCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    
                    Text(transition.normalized.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed")
                            Spacer()
                            Text(String(format: "%.1fs", transitionDuration))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $transitionDuration, in: 0.2...2.0, step: 0.1)
                    }
                } header: {
                    Label("Transition", systemImage: "arrow.right.arrow.left")
                }
            }
            .navigationTitle(isEditing ? "Edit Live Website" : "Live Website")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add to Playlist") {
                        if isEditing {
                            updateItem()
                        } else {
                            addToPlaylist()
                        }
                        dismiss()
                    }
                    .disabled(!isValidURL)
                }
            }
            .onAppear {
                loadExistingData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isURLFieldFocused = true
                }
            }
            .sheet(isPresented: $showTestView) {
                if let url = URL(string: urlString) {
                    URLTestView(url: url) { result in
                        testResult = result
                    }
                    .preferredColorScheme(.dark)
                }
            }
        }
    }
    
    @ViewBuilder
    private func testResultBadge(_ result: URLTestResult) -> some View {
        HStack(spacing: 4) {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(result.isSuccess ? "OK" : "Warning")
                .font(.caption)
        }
        .foregroundColor(result.isSuccess ? .green : .orange)
    }
    
    private func addToPlaylist() {
        guard let url = URL(string: urlString) else { return }
        
        let name = itemName.isEmpty ? (url.host ?? urlString) : itemName
        
        let item = PlaylistItem.liveWeb(
            name: name,
            url: url,
            duration: duration,
            preloadSeconds: preloadSeconds,
            transition: transition,
            transitionDuration: transitionDuration
        )
        
        playlistManager.addItem(item)
        playlistManager.savePlaylist()
    }
    
    private func updateItem() {
        guard let index = editingIndex else { return }
        guard let url = URL(string: urlString) else { return }
        
        let name = itemName.isEmpty ? (url.host ?? urlString) : itemName
        
        playlistManager.items[index].name = name
        playlistManager.items[index].contentType = .liveWeb(url: url, preloadSeconds: preloadSeconds)
        playlistManager.items[index].duration = duration
        playlistManager.items[index].transition = transition
        playlistManager.items[index].transitionDuration = transitionDuration
        playlistManager.savePlaylist()
    }
    
    private func loadExistingData() {
        if let url = existingURL {
            urlString = url.absoluteString
            isValidURL = true
        }
        
        if let index = editingIndex, index < playlistManager.items.count {
            let item = playlistManager.items[index]
            itemName = item.name
            duration = item.duration
            transition = item.transition.normalized
            transitionDuration = item.transitionDuration
            
            // Get preload seconds from content type
            if case .liveWeb(_, let preload) = item.contentType {
                preloadSeconds = preload
            }
        }
    }
}

// MARK: - URL Test Result

struct URLTestResult {
    let isSuccess: Bool
    let message: String
}

// MARK: - URL Test View

struct URLTestView: View {
    let url: URL
    let onResult: (URLTestResult) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var loadState: LoadState = .loading
    @State private var errorMessage: String?
    
    enum LoadState {
        case loading
        case success
        case failed
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Web view
                URLTestWebView(
                    url: url,
                    onSuccess: {
                        loadState = .success
                    },
                    onError: { error in
                        loadState = .failed
                        errorMessage = error
                    }
                )
                
                // Loading overlay
                if loadState == .loading {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Testing URL...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Result overlay
                if loadState == .success || loadState == .failed {
                    VStack {
                        Spacer()
                        
                        resultCard
                            .padding()
                    }
                }
            }
            .navigationTitle("Test URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let result: URLTestResult
                        if loadState == .success {
                            result = URLTestResult(isSuccess: true, message: "Website loaded successfully!")
                        } else {
                            result = URLTestResult(isSuccess: false, message: errorMessage ?? "Website may not display correctly")
                        }
                        onResult(result)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var resultCard: some View {
        HStack(spacing: 12) {
            Image(systemName: loadState == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(loadState == .success ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(loadState == .success ? "Loaded Successfully" : "Load Issue Detected")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(loadState == .success 
                     ? "This website should display correctly in your playlist."
                     : errorMessage ?? "This website may not display correctly. Some sites block embedded viewing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

// MARK: - URL Test Web View

struct URLTestWebView: UIViewRepresentable {
    let url: URL
    let onSuccess: () -> Void
    let onError: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        
        // Use desktop user agent
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        webView.load(request)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: URLTestWebView
        var hasReported = false
        
        init(_ parent: URLTestWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasReported else { return }
            hasReported = true
            
            // Check if we loaded an error page by checking the content
            webView.evaluateJavaScript("document.body.innerText.length") { result, error in
                DispatchQueue.main.async {
                    if let length = result as? Int, length > 100 {
                        self.parent.onSuccess()
                    } else if error != nil {
                        self.parent.onError("Page content couldn't be verified")
                    } else {
                        self.parent.onSuccess()
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !hasReported else { return }
            hasReported = true
            parent.onError(friendlyError(from: error))
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard !hasReported else { return }
            hasReported = true
            parent.onError(friendlyError(from: error))
        }
        
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
        
        private func friendlyError(from error: Error) -> String {
            let nsError = error as NSError
            
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection"
            case NSURLErrorTimedOut:
                return "Connection timed out"
            case NSURLErrorCannotFindHost:
                return "Website not found"
            case NSURLErrorSecureConnectionFailed:
                return "Secure connection failed"
            case NSURLErrorServerCertificateUntrusted:
                return "Certificate not trusted"
            case 102: // Frame load interrupted
                return "Site may block embedded viewing"
            case 204: // Plugin handled load
                return "Site requires special handling"
            default:
                if nsError.domain == "WebKitErrorDomain" {
                    return "Site may block embedded viewing"
                }
                return "Unable to load: \(nsError.localizedDescription)"
            }
        }
    }
}

// MARK: - CRAWL EDITOR VIEW REMOVED
// CrawlEditorView has been removed from this file.
// Crawl is now a playlist-level setting, not a content type.
// Use CrawlEditorSheet.swift instead, accessed via the crawl pill in the control panel.

// MARK: - Preview

#Preview {
    ContentTemplatesView(playlistManager: PlaylistManager(items: []))
}
