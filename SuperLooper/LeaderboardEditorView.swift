//
//  LeaderboardEditorView.swift
//  Super Looper
//
//  Form for creating and editing Leaderboard content
//

import SwiftUI
import UniformTypeIdentifiers

struct LeaderboardEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    // Edit mode
    var editingIndex: Int?
    var existingData: LeaderboardData?
    
    // Form state
    @State private var title: String = "Top Performers"
    @State private var subtitle: String = ""
    @State private var entries: [LeaderboardEntry] = []
    @State private var maxDisplayCount: Int = 10
    @State private var animationStyle: LeaderboardAnimation = .countUp
    @State private var showScores: Bool = true
    @State private var scoreLabel: String = "points"
    @State private var duration: Double = 15
    @State private var itemName: String = ""
    @State private var transition: TransitionType = .dissolve
    @State private var transitionDuration: Double = 0.5
    
    // Custom colors
    @State private var useCustomColors: Bool = false
    @State private var customBackgroundColor: String = "#1A1A2E"
    @State private var customTextColor: String = "#FFFFFF"
    @State private var customAccentColor: String = "#FFD700"
    @State private var customHighlightColor: String = "#FF6B6B"
    
    // UI state
    @State private var showPreview: Bool = false
    @State private var showAddEntry: Bool = false
    @State private var showCSVImport: Bool = false
    
    // Brand settings
    @ObservedObject private var brandManager = BrandSettingsManager.shared
    
    private var isEditing: Bool { editingIndex != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Header Info
                Section {
                    TextField("Leaderboard Title", text: $title)
                        .font(.headline)
                    
                    TextField("Subtitle (optional)", text: $subtitle)
                } header: {
                    Label("Header", systemImage: "trophy.fill")
                }
                
                // MARK: - Entries
                Section {
                    // Entry list
                    if entries.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "person.3")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                Text("No entries yet")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: 12) {
                                // Rank (based on score)
                                let rank = entries.sorted { $0.score > $1.score }.firstIndex(where: { $0.id == entry.id }).map { $0 + 1 } ?? (index + 1)
                                Text("#\(rank)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30)
                                
                                // Editable name
                                TextField("Name", text: Binding(
                                    get: { entries[safe: index]?.name ?? "" },
                                    set: { newValue in
                                        if index < entries.count {
                                            entries[index].name = newValue
                                        }
                                    }
                                ))
                                .fontWeight(.medium)
                                
                                // Editable score
                                TextField("Score", text: Binding(
                                    get: { entries[safe: index].map { String($0.score) } ?? "" },
                                    set: { newValue in
                                        if index < entries.count, let score = Int(newValue) {
                                            entries[index].score = score
                                        }
                                    }
                                ))
                                .keyboardType(.numberPad)
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            }
                        }
                        .onDelete { indexSet in
                            entries.remove(atOffsets: indexSet)
                        }
                    }
                    
                    // Add buttons
                    HStack(spacing: 12) {
                        Button {
                            showAddEntry = true
                        } label: {
                            Label("Add Entry", systemImage: "plus.circle.fill")
                        }
                        
                        Spacer()
                        
                        Button {
                            showCSVImport = true
                        } label: {
                            Label("Import CSV", systemImage: "doc.badge.arrow.up")
                        }
                    }
                    .buttonStyle(.borderless)
                } header: {
                    HStack {
                        Label("Entries", systemImage: "list.number")
                        Spacer()
                        Text("\(entries.count) teams")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - Display Options
                Section {
                    // Top 5 or Top 10 picker
                    Picker("Display Count", selection: $maxDisplayCount) {
                        Text("Top 5").tag(5)
                        Text("Top 10").tag(10)
                    }
                    .pickerStyle(.segmented)
                    
                    // Animation style
                    Picker("Animation Style", selection: $animationStyle) {
                        ForEach(LeaderboardAnimation.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    
                    // Show scores toggle
                    Toggle("Show Scores", isOn: $showScores)
                    
                    if showScores {
                        TextField("Score Label (e.g., points, sales)", text: $scoreLabel)
                    }
                } header: {
                    Label("Display Options", systemImage: "slider.horizontal.3")
                }
                
                // MARK: - Appearance
                Section {
                    Toggle("Use Custom Colors", isOn: $useCustomColors)
                    
                    if useCustomColors {
                        ColorPickerRow(label: "Background", hexColor: $customBackgroundColor)
                        ColorPickerRow(label: "Text", hexColor: $customTextColor)
                        ColorPickerRow(label: "Accent", hexColor: $customAccentColor)
                        ColorPickerRow(label: "Highlight (Top 3)", hexColor: $customHighlightColor)
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
                        Slider(value: $duration, in: 5...60, step: 1)
                    }
                    
                    TextField("Item name in playlist", text: $itemName)
                } header: {
                    Label("Settings", systemImage: "gearshape")
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
                            Label("Preview Leaderboard", systemImage: "eye")
                            Spacer()
                        }
                    }
                    
                    // Mini preview
                    LeaderboardMiniPreview(
                        data: currentLeaderboardData,
                        brandSettings: brandManager.settings
                    )
                    .frame(height: 250)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Label("Preview", systemImage: "rectangle.on.rectangle")
                }
            }
            .navigationTitle(isEditing ? "Edit Leaderboard" : "Leaderboard")
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
                    .disabled(title.isEmpty || entries.isEmpty)
                }
            }
            .onAppear {
                setupDefaults()
                loadExistingData()
            }
            .sheet(isPresented: $showAddEntry) {
                AddEntrySheet(entries: $entries)
            }
            .sheet(isPresented: $showCSVImport) {
                CSVImportSheet(entries: $entries)
            }
            .sheet(isPresented: $showPreview) {
                LeaderboardFullPreview(
                    data: currentLeaderboardData,
                    brandSettings: brandManager.settings
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentLeaderboardData: LeaderboardData {
        LeaderboardData(
            title: title.isEmpty ? "Leaderboard" : title,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            entries: entries,
            maxDisplayCount: maxDisplayCount,
            animationStyle: animationStyle,
            showScores: showScores,
            scoreLabel: scoreLabel.isEmpty ? nil : scoreLabel,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil,
            customAccentColor: useCustomColors ? customAccentColor : nil,
            customHighlightColor: useCustomColors ? customHighlightColor : nil
        )
    }
    
    // MARK: - Setup
    
    private func setupDefaults() {
        customBackgroundColor = brandManager.settings.backgroundColor
        customTextColor = brandManager.settings.textColor
        customAccentColor = brandManager.settings.accentColor
    }
    
    private func loadExistingData() {
        if let data = existingData {
            title = data.title
            subtitle = data.subtitle ?? ""
            entries = data.entries
            maxDisplayCount = data.maxDisplayCount
            animationStyle = data.animationStyle
            showScores = data.showScores
            scoreLabel = data.scoreLabel ?? "points"
            useCustomColors = !data.usesBrandColors
            if let bg = data.customBackgroundColor { customBackgroundColor = bg }
            if let text = data.customTextColor { customTextColor = text }
            if let accent = data.customAccentColor { customAccentColor = accent }
            if let highlight = data.customHighlightColor { customHighlightColor = highlight }
        }
        
        if let index = editingIndex, index < playlistManager.items.count {
            let item = playlistManager.items[index]
            itemName = item.name
            duration = item.duration
            transition = item.transition.normalized
            transitionDuration = item.transitionDuration
        }
    }
    
    // MARK: - Actions
    
    private func addToPlaylist() {
        let name = itemName.isEmpty ? title : itemName
        
        let item = PlaylistItem(
            name: name,
            contentType: .leaderboard(data: currentLeaderboardData),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
        
        playlistManager.addItem(item)
        playlistManager.savePlaylist()
    }
    
    private func updateItem() {
        guard let index = editingIndex else { return }
        
        let name = itemName.isEmpty ? title : itemName
        
        playlistManager.items[index].name = name
        playlistManager.items[index].contentType = .leaderboard(data: currentLeaderboardData)
        playlistManager.items[index].duration = duration
        playlistManager.items[index].transition = transition
        playlistManager.items[index].transitionDuration = transitionDuration
        playlistManager.savePlaylist()
    }
}

// MARK: - Animation Display Names

extension LeaderboardAnimation {
    var displayName: String {
        switch self {
        case .countUp: return "Count Up"
        case .revealBottomToTop: return "Reveal 10→1"
        case .revealTopToBottom: return "Reveal 1→10"
        case .fadeIn: return "Fade In"
        case .slideIn: return "Slide In"
        }
    }
}

// MARK: - Add Entry Sheet

struct AddEntrySheet: View {
    @Binding var entries: [LeaderboardEntry]
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var score: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Team or Person Name", text: $name)
                    
                    TextField("Score", text: $score)
                        .keyboardType(.numberPad)
                } header: {
                    Text("New Entry")
                }
            }
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let scoreInt = Int(score), !name.isEmpty {
                            let entry = LeaderboardEntry(name: name, score: scoreInt)
                            entries.append(entry)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty || Int(score) == nil)
                }
            }
        }
    }
}

// MARK: - Edit Entry Sheet

struct EditEntrySheet: View {
    let entry: LeaderboardEntry
    @Binding var entries: [LeaderboardEntry]
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var score: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Team or Person Name", text: $name)
                    
                    TextField("Score", text: $score)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Edit Entry")
                }
                
                Section {
                    Button(role: .destructive) {
                        entries.removeAll { $0.id == entry.id }
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Entry")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let index = entries.firstIndex(where: { $0.id == entry.id }),
                           let scoreInt = Int(score) {
                            entries[index].name = name
                            entries[index].score = scoreInt
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty || Int(score) == nil)
                }
            }
            .onAppear {
                name = entry.name
                score = String(entry.score)
            }
        }
    }
}

// MARK: - CSV Import Sheet

struct CSVImportSheet: View {
    @Binding var entries: [LeaderboardEntry]
    @Environment(\.dismiss) private var dismiss
    
    @State private var csvText: String = ""
    @State private var showFilePicker = false
    @State private var importError: String?
    @State private var previewEntries: [LeaderboardEntry] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Import teams and scores from a CSV file or paste CSV text directly.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Choose CSV File", systemImage: "doc.badge.arrow.up")
                    }
                } header: {
                    Text("Import File")
                }
                
                Section {
                    TextEditor(text: $csvText)
                        .frame(minHeight: 120)
                        .font(.system(.body, design: .monospaced))
                    
                    Button("Parse CSV") {
                        parseCSV()
                    }
                    .disabled(csvText.isEmpty)
                } header: {
                    Text("Or Paste CSV Text")
                } footer: {
                    Text("Format: Name,Score (one per line)\nExample:\nTeam Alpha,1500\nTeam Beta,1200")
                        .font(.caption)
                }
                
                if let error = importError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                if !previewEntries.isEmpty {
                    Section {
                        ForEach(previewEntries) { entry in
                            HStack {
                                Text(entry.name)
                                Spacer()
                                Text("\(entry.score)")
                                    .foregroundColor(.blue)
                            }
                        }
                    } header: {
                        Text("Preview (\(previewEntries.count) entries)")
                    }
                }
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        entries.append(contentsOf: previewEntries)
                        dismiss()
                    }
                    .disabled(previewEntries.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }
    
    private func parseCSV() {
        importError = nil
        previewEntries = []
        
        let lines = csvText.components(separatedBy: .newlines)
        var parsed: [LeaderboardEntry] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            // Try comma separator
            var parts = trimmed.components(separatedBy: ",")
            
            // Try tab separator if comma didn't work
            if parts.count < 2 {
                parts = trimmed.components(separatedBy: "\t")
            }
            
            if parts.count >= 2 {
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                let scoreStr = parts[1].trimmingCharacters(in: .whitespaces)
                
                if let score = Int(scoreStr), !name.isEmpty {
                    parsed.append(LeaderboardEntry(name: name, score: score))
                }
            }
        }
        
        if parsed.isEmpty {
            importError = "No valid entries found. Check format: Name,Score"
        } else {
            previewEntries = parsed
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                csvText = try String(contentsOf: url, encoding: .utf8)
                parseCSV()
            } catch {
                importError = "Failed to read file: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            importError = "Failed to open file: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mini Preview

struct LeaderboardMiniPreview: View {
    let data: LeaderboardData
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
    
    private var accentColor: Color {
        if data.usesBrandColors {
            return brandSettings.accentSwiftUIColor
        } else {
            return colorFromHex(data.customAccentColor ?? brandSettings.accentColor)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Title
            Text(data.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(textColor)
            
            if let subtitle = data.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.7))
            }
            
            // Entries
            VStack(spacing: 4) {
                ForEach(Array(data.rankedEntries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    HStack {
                        Text("#\(index + 1)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(index < 3 ? accentColor : textColor.opacity(0.6))
                            .frame(width: 24)
                        
                        Text(entry.name)
                            .font(.caption)
                            .foregroundColor(textColor)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if data.showScores {
                            Text("\(entry.score)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(accentColor)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
                
                if data.entries.count > 5 {
                    Text("+ \(data.entries.count - 5) more...")
                        .font(.caption2)
                        .foregroundColor(textColor.opacity(0.5))
                }
            }
            .padding(.top, 4)
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

// MARK: - Full Preview

struct LeaderboardFullPreview: View {
    let data: LeaderboardData
    let brandSettings: BrandSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Rendered HTML preview
            HTMLPreviewView(html: LeaderboardRenderer.render(data: data, brandSettings: brandSettings))
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

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    LeaderboardEditorView(playlistManager: PlaylistManager(items: []))
}
