//
//  TitleSlideEditorView.swift
//  Super Looper
//
//  Form for creating and editing Title Slide content
//

import SwiftUI

struct TitleSlideEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    // Edit mode - if provided, we're editing an existing item
    var editingIndex: Int?
    var existingData: TitleSlideData?
    
    // Form state
    @State private var headline: String = ""
    @State private var subheadline: String = ""
    @State private var bodyText: String = ""
    @State private var duration: Double = 8
    @State private var itemName: String = ""
    @State private var transition: TransitionType = .dissolve
    @State private var transitionDuration: Double = 0.5
    
    // Custom colors toggle
    @State private var useCustomColors: Bool = false
    @State private var customBackgroundColor: String = "#1A1A2E"
    @State private var customTextColor: String = "#FFFFFF"
    
    // Preview state
    @State private var showPreview: Bool = false
    
    // Brand settings for defaults
    @ObservedObject private var brandManager = BrandSettingsManager.shared
    
    private var isEditing: Bool { editingIndex != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Content
                Section {
                    TextField("Main headline", text: $headline, axis: .vertical)
                        .font(.headline)
                    
                    TextField("Subheadline (optional)", text: $subheadline)
                    
                    TextField("Body text (optional)", text: $bodyText, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Label("Content", systemImage: "text.alignleft")
                }
                
                // MARK: - Appearance
                Section {
                    Toggle("Use Custom Colors", isOn: $useCustomColors)
                    
                    if useCustomColors {
                        ColorPickerRow(
                            label: "Background",
                            hexColor: $customBackgroundColor
                        )
                        
                        ColorPickerRow(
                            label: "Text",
                            hexColor: $customTextColor
                        )
                    } else {
                        HStack {
                            Text("Using brand colors")
                                .foregroundColor(.secondary)
                            Spacer()
                            Circle()
                                .fill(brandManager.settings.backgroundSwiftUIColor)
                                .frame(width: 20, height: 20)
                            Circle()
                                .fill(brandManager.settings.textSwiftUIColor)
                                .frame(width: 20, height: 20)
                        }
                    }
                } header: {
                    Label("Appearance", systemImage: "paintbrush")
                }
                
                // MARK: - Settings
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Display Duration")
                            Spacer()
                            Text("\(Int(duration)) seconds")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $duration, in: 3...30, step: 1)
                    }
                    
                    TextField("Item name in playlist", text: $itemName)
                } header: {
                    Label("Settings", systemImage: "gearshape")
                } footer: {
                    Text("The item name helps identify this slide in your playlist.")
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
                
                // MARK: - Preview
                Section {
                    Button {
                        showPreview = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Preview Slide", systemImage: "eye")
                            Spacer()
                        }
                    }
                    
                    // Mini preview
                    TitleSlidePreview(
                        data: currentSlideData,
                        brandSettings: brandManager.settings
                    )
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Label("Preview", systemImage: "rectangle.on.rectangle")
                }
            }
            .navigationTitle(isEditing ? "Edit Title Slide" : "Title Slide")
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
                    .disabled(headline.isEmpty)
                }
            }
            .onAppear {
                // Set default colors from brand settings
                customBackgroundColor = brandManager.settings.backgroundColor
                customTextColor = brandManager.settings.textColor
                
                // If editing, populate from existing data
                if let data = existingData {
                    headline = data.headline
                    subheadline = data.subheadline ?? ""
                    bodyText = data.bodyText ?? ""
                    useCustomColors = !data.usesBrandColors
                    if let bg = data.customBackgroundColor {
                        customBackgroundColor = bg
                    }
                    if let text = data.customTextColor {
                        customTextColor = text
                    }
                }
                
                // Get existing item name and duration
                if let index = editingIndex, index < playlistManager.items.count {
                    let item = playlistManager.items[index]
                    itemName = item.name
                    duration = item.duration
                    transition = item.transition.normalized
                    transitionDuration = item.transitionDuration
                }
            }
            .sheet(isPresented: $showPreview) {
                TitleSlideFullPreview(
                    data: currentSlideData,
                    brandSettings: brandManager.settings
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentSlideData: TitleSlideData {
        TitleSlideData(
            headline: headline.isEmpty ? "Your Headline" : headline,
            subheadline: subheadline.isEmpty ? nil : subheadline,
            bodyText: bodyText.isEmpty ? nil : bodyText,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil
        )
    }
    
    // MARK: - Actions
    
    private func addToPlaylist() {
        let name = itemName.isEmpty ? headline : itemName
        
        let data = TitleSlideData(
            headline: headline,
            subheadline: subheadline.isEmpty ? nil : subheadline,
            bodyText: bodyText.isEmpty ? nil : bodyText,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil
        )
        
        let item = PlaylistItem(
            name: name,
            contentType: .titleSlide(data: data),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
        
        playlistManager.addItem(item)
        playlistManager.savePlaylist()
    }
    
    private func updateItem() {
        guard let index = editingIndex else { return }
        
        let name = itemName.isEmpty ? headline : itemName
        
        let data = TitleSlideData(
            headline: headline,
            subheadline: subheadline.isEmpty ? nil : subheadline,
            bodyText: bodyText.isEmpty ? nil : bodyText,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil
        )
        
        // Update the item in place
        playlistManager.items[index].name = name
        playlistManager.items[index].contentType = .titleSlide(data: data)
        playlistManager.items[index].duration = duration
        playlistManager.items[index].transition = transition
        playlistManager.items[index].transitionDuration = transitionDuration
        playlistManager.savePlaylist()
    }
}

// MARK: - Color Picker Row (simplified)

struct ColorPickerRow: View {
    let label: String
    @Binding var hexColor: String
    
    @State private var selectedColor: Color = .blue
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(hexColor.uppercased())
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundColor(.secondary)
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
        }
        .onAppear {
            selectedColor = colorFromHex(hexColor)
        }
        .onChange(of: selectedColor) { _, newColor in
            hexColor = hexFromColor(newColor)
        }
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
    
    private func hexFromColor(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Title Slide Preview (mini, in-form)

struct TitleSlidePreview: View {
    let data: TitleSlideData
    let brandSettings: BrandSettings
    
    private var bgColor: Color {
        if data.usesBrandColors {
            return brandSettings.backgroundSwiftUIColor
        } else {
            return colorFromHex(data.customBackgroundColor ?? brandSettings.backgroundColor)
        }
    }
    
    private var textColor: Color {
        if data.usesBrandColors {
            return brandSettings.textSwiftUIColor
        } else {
            return colorFromHex(data.customTextColor ?? brandSettings.textColor)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(data.headline)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
            
            if let subheadline = data.subheadline {
                Text(subheadline)
                    .font(.subheadline)
                    .foregroundColor(textColor.opacity(0.8))
            }
            
            if let body = data.bodyText {
                Text(body)
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(bgColor)
        .cornerRadius(12)
        .padding(8)
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Title Slide Full Preview (sheet)

struct TitleSlideFullPreview: View {
    let data: TitleSlideData
    let brandSettings: BrandSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Rendered HTML preview
            HTMLPreviewView(html: TitleSlideRenderer.render(data: data, brandSettings: brandSettings))
                .ignoresSafeArea()
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8), .black.opacity(0.3))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - HTML Preview View

struct HTMLPreviewView: UIViewRepresentable {
    let html: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

import WebKit

// MARK: - Preview

#Preview {
    TitleSlideEditorView(playlistManager: PlaylistManager(items: []))
}
