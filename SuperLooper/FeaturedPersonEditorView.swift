//
//  FeaturedPersonEditorView.swift
//  Super Looper
//
//  Form for creating and editing Featured Person content
//

import SwiftUI
import PhotosUI

struct FeaturedPersonEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    // Edit mode - if provided, we're editing an existing item
    var editingIndex: Int?
    var existingData: FeaturedPersonData?
    
    // Form state
    @State private var featureTitle: String = ""
    @State private var name: String = ""
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var duration: Double = 12
    @State private var itemName: String = ""
    @State private var transition: TransitionType = .dissolve
    @State private var transitionDuration: Double = 0.5
    
    // Photo state
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var photoFilename: String?
    
    // Custom colors toggle
    @State private var useCustomColors: Bool = false
    @State private var customBackgroundColor: String = "#1A1A2E"
    @State private var customTextColor: String = "#FFFFFF"
    @State private var customAccentColor: String = "#FFD700"
    
    // Preview state
    @State private var showPreview: Bool = false
    
    // Focus state
    @FocusState private var isNameFieldFocused: Bool
    
    // Brand settings for defaults
    @ObservedObject private var brandManager = BrandSettingsManager.shared
    
    private var isEditing: Bool { editingIndex != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Photo
                Section {
                    HStack {
                        // Photo preview
                        if let image = photoImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.title)
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label(photoImage == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                            }
                            
                            if photoImage != nil {
                                Button(role: .destructive) {
                                    photoImage = nil
                                    photoFilename = nil
                                    selectedPhoto = nil
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Photo", systemImage: "person.crop.square")
                }
                
                // MARK: - Feature Title
                Section {
                    TextField("e.g., Employee of the Week", text: $featureTitle)
                        .textInputAutocapitalization(.words)
                } header: {
                    Label("Feature Title (Optional)", systemImage: "star")
                } footer: {
                    Text("Displayed prominently above the person's name")
                }
                
                // MARK: - Person Info
                Section {
                    TextField("Full name", text: $name)
                        .focused($isNameFieldFocused)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Title or role", text: $title)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Additional info (optional)", text: $subtitle)
                } header: {
                    Label("Person", systemImage: "person")
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
                        
                        ColorPickerRow(
                            label: "Accent",
                            hexColor: $customAccentColor
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
                                .fill(brandManager.settings.accentSwiftUIColor)
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
                        Slider(value: $duration, in: 5...60, step: 1)
                    }
                    
                    TextField("Item name in playlist", text: $itemName)
                } header: {
                    Label("Settings", systemImage: "gearshape")
                } footer: {
                    Text("The item name helps identify this slide in your playlist.")
                }
                
                // MARK: - Transition
                TransitionPickerSection(transition: $transition, transitionDuration: $transitionDuration)
                
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
                    FeaturedPersonPreview(
                        data: currentData,
                        brandSettings: brandManager.settings,
                        photoImage: photoImage
                    )
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Label("Preview", systemImage: "rectangle.on.rectangle")
                }
            }
            .navigationTitle(isEditing ? "Edit Featured Person" : "Featured Person")
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
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                // Set default colors from brand settings
                customBackgroundColor = brandManager.settings.backgroundColor
                customTextColor = brandManager.settings.textColor
                customAccentColor = brandManager.settings.accentColor
                
                // If editing, populate from existing data
                if let data = existingData {
                    featureTitle = data.featureTitle ?? ""
                    name = data.name
                    title = data.title
                    subtitle = data.subtitle ?? ""
                    useCustomColors = !data.usesBrandColors
                    if let bg = data.customBackgroundColor {
                        customBackgroundColor = bg
                    }
                    if let text = data.customTextColor {
                        customTextColor = text
                    }
                    if let accent = data.customAccentColor {
                        customAccentColor = accent
                    }
                    
                    // Load existing photo
                    if let filename = data.photoFilename {
                        photoFilename = filename
                        photoImage = playlistManager.loadImage(filename: filename)
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
                
                // Focus name field after brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFieldFocused = true
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            photoImage = image
                            photoFilename = nil // Mark as new photo
                        }
                    }
                }
            }
            .sheet(isPresented: $showPreview) {
                FeaturedPersonFullPreview(
                    data: currentData,
                    brandSettings: brandManager.settings,
                    photoImage: photoImage
                )
                .preferredColorScheme(.dark)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentData: FeaturedPersonData {
        FeaturedPersonData(
            featureTitle: featureTitle.isEmpty ? nil : featureTitle,
            name: name.isEmpty ? "Name" : name,
            title: title.isEmpty ? "Title" : title,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            photoFilename: photoFilename,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil,
            customAccentColor: useCustomColors ? customAccentColor : nil
        )
    }
    
    // MARK: - Actions
    
    private func addToPlaylist() {
        // Save photo if provided
        var savedPhotoFilename: String? = nil
        if let image = photoImage {
            savedPhotoFilename = savePhoto(image)
        }
        
        let displayName = itemName.isEmpty ? name : itemName
        
        let data = FeaturedPersonData(
            featureTitle: featureTitle.isEmpty ? nil : featureTitle,
            name: name,
            title: title,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            photoFilename: savedPhotoFilename,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil,
            customAccentColor: useCustomColors ? customAccentColor : nil
        )
        
        let item = PlaylistItem(
            name: displayName,
            contentType: .featuredPerson(data: data),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
        
        playlistManager.addItem(item)
        playlistManager.savePlaylist()
    }
    
    private func updateItem() {
        guard let index = editingIndex else { return }
        
        // Save photo if it's new (photoFilename is nil but photoImage exists)
        var savedPhotoFilename: String? = photoFilename
        if let image = photoImage, photoFilename == nil {
            savedPhotoFilename = savePhoto(image)
        }
        
        let displayName = itemName.isEmpty ? name : itemName
        
        let data = FeaturedPersonData(
            featureTitle: featureTitle.isEmpty ? nil : featureTitle,
            name: name,
            title: title,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            photoFilename: savedPhotoFilename,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil,
            customAccentColor: useCustomColors ? customAccentColor : nil
        )
        
        // Update the item in place
        playlistManager.items[index].name = displayName
        playlistManager.items[index].contentType = .featuredPerson(data: data)
        playlistManager.items[index].duration = duration
        playlistManager.items[index].transition = transition
        playlistManager.items[index].transitionDuration = transitionDuration
        playlistManager.savePlaylist()
    }
    
    private func savePhoto(_ image: UIImage) -> String? {
        let filename = "featured_\(UUID().uuidString).jpg"
        if playlistManager.saveImage(image, filename: filename) != nil {
            return filename
        }
        return nil
    }
}

// MARK: - Featured Person Preview (mini, in-form)

struct FeaturedPersonPreview: View {
    let data: FeaturedPersonData
    let brandSettings: BrandSettings
    var photoImage: UIImage?
    
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
    
    private var accentColor: Color {
        if data.usesBrandColors {
            return brandSettings.accentSwiftUIColor
        } else {
            return colorFromHex(data.customAccentColor ?? brandSettings.accentColor)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Award
            Text("FEATURED")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(accentColor)
                .tracking(2)
            
            // Photo
            if let image = photoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Text("👤")
                            .font(.title)
                    )
            }
            
            // Name
            Text(data.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(textColor)
            
            // Title
            Text(data.title)
                .font(.caption)
                .foregroundColor(textColor.opacity(0.8))
            
            // Subtitle
            if let subtitle = data.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(textColor.opacity(0.6))
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

// MARK: - Featured Person Full Preview (sheet)

struct FeaturedPersonFullPreview: View {
    let data: FeaturedPersonData
    let brandSettings: BrandSettings
    var photoImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Rendered HTML preview
            let photoBase64 = photoImage?.jpegData(compressionQuality: 0.8)?.base64EncodedString()
            HTMLPreviewView(html: FeaturedPersonRenderer.render(
                data: data,
                brandSettings: brandSettings,
                photoBase64: photoBase64
            ))
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

// MARK: - Preview

#Preview {
    FeaturedPersonEditorView(playlistManager: PlaylistManager(items: []))
}
