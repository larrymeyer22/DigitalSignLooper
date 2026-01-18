//
//  WebViews.swift
//  Super Looper
//
//  HTML and Web content views using WKWebView
//

import SwiftUI
import WebKit

// MARK: - HTML Content View

struct HTMLContentView: View {
    let htmlContent: String
    
    var body: some View {
        WebViewRepresentable(content: .html(htmlContent))
    }
}

// MARK: - Web Content View

struct WebContentView: View {
    let url: URL
    
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        ZStack {
            WebViewRepresentable(
                content: .url(url),
                isLoading: $isLoading,
                hasError: $loadError
            )
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
            
            if loadError {
                errorView
            }
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Unable to load page")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(url.absoluteString)
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .lineLimit(2)
        }
        .padding()
    }
}

// MARK: - Web View Representable

struct WebViewRepresentable: UIViewRepresentable {
    enum Content {
        case html(String)
        case url(URL)
    }
    
    let content: Content
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    
    init(content: Content, isLoading: Binding<Bool> = .constant(false), hasError: Binding<Bool> = .constant(false)) {
        self.content = content
        self._isLoading = isLoading
        self._hasError = hasError
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        
        // Disable scrolling for booth display
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        switch content {
        case .html(let htmlString):
            let styledHTML = wrapHTMLWithStyles(htmlString)
            webView.loadHTMLString(styledHTML, baseURL: nil)
            
        case .url(let url):
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, hasError: $hasError)
    }
    
    /// Wraps raw HTML with basic styling for better display
    private func wrapHTMLWithStyles(_ html: String) -> String {
        // Check if HTML already has full document structure
        if html.lowercased().contains("<html") {
            return html
        }
        
        // Wrap partial HTML with basic styling
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    background-color: #000;
                    color: #fff;
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 40px;
                }
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var hasError: Bool
        
        init(isLoading: Binding<Bool>, hasError: Binding<Bool>) {
            self._isLoading = isLoading
            self._hasError = hasError
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            hasError = false
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            hasError = true
            print("WebView failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            hasError = true
            print("WebView failed provisional navigation: \(error.localizedDescription)")
        }
    }
}

// MARK: - Previews

#Preview("HTML Content") {
    HTMLContentView(htmlContent: """
        <div style="text-align: center;">
            <h1 style="font-size: 48px; margin-bottom: 20px;">Welcome!</h1>
            <p style="font-size: 24px; color: #888;">This is HTML content</p>
        </div>
    """)
}

#Preview("Web Content") {
    WebContentView(url: URL(string: "https://apple.com")!)
}
