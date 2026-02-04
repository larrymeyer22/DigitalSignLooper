//
//  CrawlEditorSheet.swift
//  Super Looper
//
//  Editor for bottom crawl messages
//

import SwiftUI

struct CrawlEditorSheet: View {
    @ObservedObject var playlistManager: PlaylistManager
    @ObservedObject private var brandManager = BrandSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var newItemText: String = ""
    @FocusState private var isMessageFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                // Enable Toggle
                Section {
                    Toggle(isOn: $playlistManager.crawlData.isEnabled) {
                        Label("Enable Crawl", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                }
                
                // Messages
                Section {
                    HStack {
                        TextField("Add message...", text: $newItemText)
                            .focused($isMessageFieldFocused)
                            .submitLabel(.done)
                            .onSubmit { addItem() }
                        
                        Button(action: addItem) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(newItemText.isEmpty ? .gray : .blue)
                        }
                        .disabled(newItemText.isEmpty)
                    }
                    
                    ForEach(playlistManager.crawlData.items.indices, id: \.self) { index in
                        Text(playlistManager.crawlData.items[index])
                    }
                    .onDelete { indexSet in
                        playlistManager.crawlData.items.remove(atOffsets: indexSet)
                    }
                    .onMove { from, to in
                        playlistManager.crawlData.items.move(fromOffsets: from, toOffset: to)
                    }
                } header: {
                    Text("Messages")
                } footer: {
                    Text("Add messages to appear in the crawl one at a time by typing the message and tapping the + sign. Messages scroll continuously across the bottom of the screen.")
                }
                
                // Appearance
                Section("Appearance") {
                    Picker("Size", selection: $playlistManager.crawlData.size) {
                        ForEach(CrawlSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    
                    Picker("Speed", selection: $playlistManager.crawlData.speed) {
                        ForEach(CrawlSpeed.allCases, id: \.self) { speed in
                            Text(speed.rawValue).tag(speed)
                        }
                    }
                    
                    // Background color swatches
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Background")
                            .font(.subheadline)
                        
                        HStack(spacing: 12) {
                            ForEach(CrawlBackgroundStyle.allCases, id: \.self) { style in
                                ColorSwatchButton(
                                    style: style,
                                    isSelected: playlistManager.crawlData.backgroundStyle == style,
                                    brandSettings: brandManager.settings,
                                    customHex: playlistManager.crawlData.customBackgroundColor
                                ) {
                                    playlistManager.crawlData.backgroundStyle = style
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Custom color picker (shown when custom is selected)
                    if playlistManager.crawlData.backgroundStyle == .custom {
                        CrawlColorPickerRow(
                            label: "Custom Color",
                            hexColor: $playlistManager.crawlData.customBackgroundColor
                        )
                    }
                }
                
                // Clear
                if !playlistManager.crawlData.items.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            playlistManager.crawlData.items.removeAll()
                            playlistManager.crawlData.isEnabled = false
                        } label: {
                            HStack {
                                Spacer()
                                Text("Clear All Messages")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bottom Crawl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        playlistManager.savePlaylist()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Focus message field after brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isMessageFieldFocused = true
                }
            }
        }
    }
    
    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        playlistManager.crawlData.items.append(trimmed)
        newItemText = ""
    }
}

// MARK: - Color Swatch Button

struct ColorSwatchButton: View {
    let style: CrawlBackgroundStyle
    let isSelected: Bool
    let brandSettings: BrandSettings
    var customHex: String = "#333333"
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if style == .custom {
                        // Rainbow gradient for custom
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                    center: .center
                                )
                            )
                            .frame(width: 40, height: 40)
                    } else {
                        Circle()
                            .fill(style.color(brandSettings: brandSettings, customHex: customHex))
                            .frame(width: 40, height: 40)
                    }
                    
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 1)
                    }
                }
                
                Text(style.shortName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Crawl Color Picker Row

struct CrawlColorPickerRow: View {
    let label: String
    @Binding var hexColor: String
    
    @State private var selectedColor: Color = .gray
    
    var body: some View {
        HStack {
            Text(label)
            
            Spacer()
            
            // Hex input
            TextField("#000000", text: $hexColor)
                .frame(width: 90)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: hexColor) { _, newValue in
                    if let color = colorFromHex(newValue) {
                        selectedColor = color
                    }
                }
            
            // Color picker
            ColorPicker("", selection: $selectedColor)
                .labelsHidden()
                .onChange(of: selectedColor) { _, newColor in
                    hexColor = colorToHex(newColor) ?? hexColor
                }
        }
        .onAppear {
            if let color = colorFromHex(hexColor) {
                selectedColor = color
            }
        }
    }
    
    private func colorFromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
    
    private func colorToHex(_ color: Color) -> String? {
        guard let components = UIColor(color).cgColor.components else { return nil }
        
        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - CrawlBackgroundStyle Extension

extension CrawlBackgroundStyle {
    var shortName: String {
        switch self {
        case .semitransparentDark: return "Dark"
        case .brandPrimary: return "Primary"
        case .brandSecondary: return "Secondary"
        case .brandAccent: return "Accent"
        case .custom: return "Custom"
        }
    }
}

#Preview {
    CrawlEditorSheet(playlistManager: PlaylistManager(items: []))
        .preferredColorScheme(.dark)
}
