//
//  CountdownEditorView.swift
//  Super Looper
//
//  Form for creating and editing Countdown Timer content
//

import SwiftUI

struct CountdownEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    // Edit mode - if provided, we're editing an existing item
    var editingIndex: Int?
    var existingData: CountdownData?
    
    // Form state
    @State private var title: String = ""
    @State private var mode: CountdownMode = .duration
    @State private var targetDate: Date = Date().addingTimeInterval(3600)
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 5
    @State private var durationSeconds: Int = 0
    @State private var showDays: Bool = false
    @State private var showHours: Bool = true
    @State private var expiredMessage: String = "Time's Up!"
    @State private var itemDuration: Double = 30
    @State private var transition: TransitionType = .dissolve
    @State private var transitionDuration: Double = 0.5
    
    // Custom colors toggle
    @State private var useCustomColors: Bool = false
    @State private var customBackgroundColor: String = "#1A1A2E"
    @State private var customTextColor: String = "#FFFFFF"
    @State private var customAccentColor: String = "#FFD700"
    
    // Focus state
    @FocusState private var isTitleFieldFocused: Bool
    
    private var isEditing: Bool { editingIndex != nil }
    
    // Computed current data
    private var currentData: CountdownData {
        CountdownData(
            title: title.isEmpty ? nil : title,
            mode: mode,
            targetDate: mode == .targetTime ? targetDate : nil,
            durationHours: durationHours,
            durationMinutes: durationMinutes,
            durationSeconds: durationSeconds,
            showDays: showDays,
            showHours: showHours,
            expiredMessage: expiredMessage,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil,
            customAccentColor: useCustomColors ? customAccentColor : nil
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Title
                Section {
                    TextField("e.g., Until Launch", text: $title)
                        .focused($isTitleFieldFocused)
                } header: {
                    Label("Title (Optional)", systemImage: "textformat")
                } footer: {
                    Text("Displayed above the countdown timer")
                }
                
                // MARK: - Mode
                Section {
                    Picker("Countdown Mode", selection: $mode) {
                        ForEach(CountdownMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("Mode", systemImage: "clock")
                }
                
                // MARK: - Target Date (for targetTime mode)
                if mode == .targetTime {
                    Section {
                        DatePicker(
                            "Target Date & Time",
                            selection: $targetDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    } header: {
                        Label("Target", systemImage: "calendar")
                    } footer: {
                        Text("Countdown will reach zero at this date and time")
                    }
                }
                
                // MARK: - Duration (for duration mode)
                if mode == .duration {
                    Section {
                        HStack {
                            VStack {
                                Text("Hours")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Hours", selection: $durationHours) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text("\(h)").tag(h)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 100)
                                .clipped()
                            }
                            
                            VStack {
                                Text("Minutes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Minutes", selection: $durationMinutes) {
                                    ForEach(0..<60, id: \.self) { m in
                                        Text("\(m)").tag(m)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 100)
                                .clipped()
                            }
                            
                            VStack {
                                Text("Seconds")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Seconds", selection: $durationSeconds) {
                                    ForEach(0..<60, id: \.self) { s in
                                        Text("\(s)").tag(s)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 100)
                                .clipped()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } header: {
                        Label("Duration", systemImage: "timer")
                    } footer: {
                        let total = durationHours * 3600 + durationMinutes * 60 + durationSeconds
                        Text("Total: \(formatDuration(total))")
                    }
                }
                
                // MARK: - Display Options
                Section {
                    Toggle("Show Days", isOn: $showDays)
                    Toggle("Show Hours", isOn: $showHours)
                } header: {
                    Label("Display Options", systemImage: "eye")
                }
                
                // MARK: - Expired Message
                Section {
                    TextField("Time's Up!", text: $expiredMessage)
                } header: {
                    Label("Message When Complete", systemImage: "checkmark.circle")
                } footer: {
                    Text("Displayed when the countdown reaches zero")
                }
                
                // MARK: - Item Duration (how long to show in playlist)
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Display Duration")
                            Spacer()
                            Text("\(Int(itemDuration)) seconds")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $itemDuration, in: 5...300, step: 5)
                    }
                } header: {
                    Label("Playlist Duration", systemImage: "play.rectangle")
                } footer: {
                    Text("How long this item displays before advancing to the next item")
                }
                
                // MARK: - Colors
                Section {
                    Toggle("Use Custom Colors", isOn: $useCustomColors)
                    
                    if useCustomColors {
                        ColorPicker("Background", selection: Binding(
                            get: { Color(hex: customBackgroundColor) },
                            set: { customBackgroundColor = $0.toHexString() }
                        ), supportsOpacity: false)
                        
                        ColorPicker("Text", selection: Binding(
                            get: { Color(hex: customTextColor) },
                            set: { customTextColor = $0.toHexString() }
                        ), supportsOpacity: false)
                        
                        ColorPicker("Accent", selection: Binding(
                            get: { Color(hex: customAccentColor) },
                            set: { customAccentColor = $0.toHexString() }
                        ), supportsOpacity: false)
                    }
                } header: {
                    Label("Appearance", systemImage: "paintbrush")
                } footer: {
                    if !useCustomColors {
                        Text("Using brand colors from settings")
                    }
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
            .navigationTitle(isEditing ? "Edit Countdown" : "New Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveCountdown()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadExistingData()
                if !isEditing {
                    isTitleFieldFocused = true
                }
            }
        }
    }
    
    // MARK: - Load Existing Data
    
    private func loadExistingData() {
        guard let data = existingData else { return }
        
        title = data.title ?? ""
        mode = data.mode
        if let target = data.targetDate {
            targetDate = target
        }
        durationHours = data.durationHours
        durationMinutes = data.durationMinutes
        durationSeconds = data.durationSeconds
        showDays = data.showDays
        showHours = data.showHours
        expiredMessage = data.expiredMessage
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
        
        // Load item duration from existing item
        if let index = editingIndex, index < playlistManager.items.count {
            itemDuration = playlistManager.items[index].duration
            transition = playlistManager.items[index].transition.normalized
            transitionDuration = playlistManager.items[index].transitionDuration
        }
    }
    
    // MARK: - Save
    
    private func saveCountdown() {
        let data = currentData
        let displayName = title.isEmpty ? "Countdown Timer" : title
        
        if let index = editingIndex, index < playlistManager.items.count {
            // Update existing item in place
            playlistManager.items[index].name = displayName
            playlistManager.items[index].contentType = .countdown(data: data)
            playlistManager.items[index].duration = itemDuration
            playlistManager.items[index].transition = transition
            playlistManager.items[index].transitionDuration = transitionDuration
            playlistManager.savePlaylist()
        } else {
            // Add new item
            let newItem = PlaylistItem(
                name: displayName,
                contentType: .countdown(data: data),
                duration: itemDuration,
                transition: transition,
                transitionDuration: transitionDuration
            )
            playlistManager.addItem(newItem)
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Color Extension for Hex Support

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
    
    func toHexString() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#FFFFFF" }
        
        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

#Preview {
    CountdownEditorView(playlistManager: PlaylistManager())
}
