//
//  BrandSettingsView.swift
//  Super Looper
//
//  UI for configuring brand colors, fonts, and logos
//

import SwiftUI
import PhotosUI

struct BrandSettingsView: View {
    @ObservedObject private var manager = BrandSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Photo picker state
    @State private var leftLogoItem: PhotosPickerItem?
    @State private var rightLogoItem: PhotosPickerItem?
    
    // Preset selection
    @State private var showingPresets = false
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Quick Start
                Section {
                    Button(action: { showingPresets = true }) {
                        HStack {
                            Image(systemName: "paintpalette")
                                .foregroundColor(.purple)
                                .frame(width: 28)
                            Text("Choose a Preset Theme")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("Quick Start")
                } footer: {
                    Text("Start with a preset and customize from there.")
                }
                
                // MARK: - Colors
                Section {
                    BrandColorRow(
                        title: "Background",
                        subtitle: "Slide backgrounds",
                        hexColor: $manager.settings.backgroundColor,
                        onSave: { manager.save() }
                    )
                    
                    BrandColorRow(
                        title: "Text",
                        subtitle: "Primary text color",
                        hexColor: $manager.settings.textColor,
                        onSave: { manager.save() }
                    )
                    
                    BrandColorRow(
                        title: "Accent",
                        subtitle: "Highlights & emphasis",
                        hexColor: $manager.settings.accentColor,
                        onSave: { manager.save() }
                    )
                    
                    BrandColorRow(
                        title: "Subtitle",
                        subtitle: "Secondary text",
                        hexColor: $manager.settings.subtitleColor,
                        onSave: { manager.save() }
                    )
                } header: {
                    Label("Colors", systemImage: "swatchpalette")
                }
                
                // MARK: - Typography
                Section {
                    Picker("Title Font", selection: $manager.settings.titleFont) {
                        ForEach(BrandSettings.FontFamily.allCases, id: \.self) { font in
                            Text(font.rawValue).tag(font)
                        }
                    }
                    .onChange(of: manager.settings.titleFont) { _, _ in
                        manager.save()
                    }
                    
                    Picker("Title Weight", selection: $manager.settings.titleFontWeight) {
                        ForEach(BrandSettings.FontWeight.allCases, id: \.self) { weight in
                            Text(weight.rawValue).tag(weight)
                        }
                    }
                    .onChange(of: manager.settings.titleFontWeight) { _, _ in
                        manager.save()
                    }
                    
                    Picker("Body Font", selection: $manager.settings.bodyFont) {
                        ForEach(BrandSettings.FontFamily.allCases, id: \.self) { font in
                            Text(font.rawValue).tag(font)
                        }
                    }
                    .onChange(of: manager.settings.bodyFont) { _, _ in
                        manager.save()
                    }
                    
                    Picker("Body Weight", selection: $manager.settings.bodyFontWeight) {
                        ForEach(BrandSettings.FontWeight.allCases, id: \.self) { weight in
                            Text(weight.rawValue).tag(weight)
                        }
                    }
                    .onChange(of: manager.settings.bodyFontWeight) { _, _ in
                        manager.save()
                    }
                } header: {
                    Label("Typography", systemImage: "textformat")
                } footer: {
                    Text("Choose fonts and weights for headlines and body text.")
                }
                
                // MARK: - Logos
                Section {
                    BrandLogoRow(
                        title: "Logo 1",
                        logoData: manager.settings.leftLogoData,
                        pickerItem: $leftLogoItem,
                        onImageSelected: { image in
                            manager.uploadLogo(image: image, position: .left)
                        },
                        onRemove: {
                            manager.removeLogo(position: .left)
                        }
                    )
                    
                    if manager.settings.leftLogoData != nil {
                        Picker("Logo 1 Position", selection: $manager.settings.logo1Placement) {
                            ForEach(BrandSettings.LogoPlacement.allCases, id: \.self) { placement in
                                Label(placement.rawValue, systemImage: placement.icon).tag(placement)
                            }
                        }
                        .onChange(of: manager.settings.logo1Placement) { _, _ in
                            manager.save()
                        }
                    }
                    
                    BrandLogoRow(
                        title: "Logo 2",
                        logoData: manager.settings.rightLogoData,
                        pickerItem: $rightLogoItem,
                        onImageSelected: { image in
                            manager.uploadLogo(image: image, position: .right)
                        },
                        onRemove: {
                            manager.removeLogo(position: .right)
                        }
                    )
                    
                    if manager.settings.rightLogoData != nil {
                        Picker("Logo 2 Position", selection: $manager.settings.logo2Placement) {
                            ForEach(BrandSettings.LogoPlacement.allCases, id: \.self) { placement in
                                Label(placement.rawValue, systemImage: placement.icon).tag(placement)
                            }
                        }
                        .onChange(of: manager.settings.logo2Placement) { _, _ in
                            manager.save()
                        }
                    }
                } header: {
                    Label("Logos", systemImage: "photo.on.rectangle")
                } footer: {
                    Text("Logos appear in the corners of generated content. Use transparent PNGs for best results.")
                }
                
                // MARK: - Preview
                Section {
                    BrandPreviewCard(settings: manager.settings)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Label("Preview", systemImage: "eye")
                }
                
                // MARK: - Reset
                Section {
                    Button(role: .destructive) {
                        manager.resetToDefaults()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset to Defaults")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Brand Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPresets) {
                PresetThemesView(manager: manager)
                    .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: - Brand Color Row

struct BrandColorRow: View {
    let title: String
    let subtitle: String
    @Binding var hexColor: String
    let onSave: () -> Void
    
    @State private var selectedColor: Color = .blue
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Hex value display
            Text(hexColor.uppercased())
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundColor(.secondary)
                .padding(.trailing, 8)
            
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 44, height: 44)
        }
        .onAppear {
            selectedColor = colorFromHex(hexColor)
        }
        .onChange(of: selectedColor) { _, newColor in
            hexColor = hexFromColor(newColor)
            onSave()
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
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Brand Logo Row

struct BrandLogoRow: View {
    let title: String
    let logoData: String?
    @Binding var pickerItem: PhotosPickerItem?
    let onImageSelected: (UIImage) -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            if let data = logoData,
               let imageData = Data(base64Encoded: data),
               let uiImage = UIImage(data: imageData) {
                // Show current logo
                HStack(spacing: 12) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Photo picker for adding logo
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Add", systemImage: "plus.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        onImageSelected(image)
                        pickerItem = nil
                    }
                }
            }
        }
    }
}

// MARK: - Brand Preview Card

struct BrandPreviewCard: View {
    let settings: BrandSettings
    
    var body: some View {
        VStack(spacing: 0) {
            // Mini preview card
            VStack(spacing: 12) {
                // Title
                Text("Sample Title")
                    .font(.title2)
                    .fontWeight(settings.titleFontWeight.swiftUIWeight)
                    .foregroundColor(settings.textSwiftUIColor)
                
                // Subtitle
                Text("Subtitle text goes here")
                    .font(.subheadline)
                    .fontWeight(settings.bodyFontWeight.swiftUIWeight)
                    .foregroundColor(settings.subtitleSwiftUIColor)
                
                // Color swatches
                HStack(spacing: 12) {
                    BrandColorSwatch(color: settings.backgroundSwiftUIColor, label: "BG")
                    BrandColorSwatch(color: settings.textSwiftUIColor, label: "Text")
                    BrandColorSwatch(color: settings.accentSwiftUIColor, label: "Accent")
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(settings.backgroundSwiftUIColor)
            .cornerRadius(12)
            .padding(16)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

struct BrandColorSwatch: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preset Themes View

struct PresetThemesView: View {
    @ObservedObject var manager: BrandSettingsManager
    @Environment(\.dismiss) private var dismiss
    
    let presets = Array(BrandSettings.presets.keys.sorted())
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(presets, id: \.self) { presetName in
                    if let preset = BrandSettings.presets[presetName] {
                        Button {
                            applyPreset(preset)
                            dismiss()
                        } label: {
                            PresetRow(name: presetName, settings: preset)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Preset Themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func applyPreset(_ preset: BrandSettings) {
        manager.settings.primaryColor = preset.primaryColor
        manager.settings.secondaryColor = preset.secondaryColor
        manager.settings.accentColor = preset.accentColor
        manager.settings.backgroundColor = preset.backgroundColor
        manager.settings.textColor = preset.textColor
        manager.settings.subtitleColor = preset.subtitleColor
        manager.save()
    }
}

struct PresetRow: View {
    let name: String
    let settings: BrandSettings
    
    var body: some View {
        HStack(spacing: 16) {
            // Color preview
            HStack(spacing: 4) {
                Circle()
                    .fill(settings.backgroundSwiftUIColor)
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(settings.textSwiftUIColor)
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(settings.accentSwiftUIColor)
                    .frame(width: 24, height: 24)
            }
            
            // Name
            Text(name)
                .fontWeight(.medium)
            
            Spacer()
            
            // Mini preview
            RoundedRectangle(cornerRadius: 4)
                .fill(settings.backgroundSwiftUIColor)
                .frame(width: 60, height: 36)
                .overlay(
                    Text("Aa")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(settings.textSwiftUIColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    BrandSettingsView()
}
