//
//  ScheduleEditorView.swift
//  Super Looper
//
//  Form for creating and editing Schedule content with rotating events
//

import SwiftUI

// MARK: - Alignment Option

enum ScheduleAlignment: String, CaseIterable {
    case center = "center"
    case left = "left"
    
    var displayName: String {
        switch self {
        case .center: return "Center"
        case .left: return "Left"
        }
    }
}

// MARK: - Schedule Editor View

struct ScheduleEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    // Edit mode
    var editingIndex: Int?
    var existingData: ScheduleData?
    
    // Form state
    @State private var events: [ScheduleEventItem] = []
    @State private var secondsPerEvent: Double = 8
    @State private var alignment: ScheduleAlignment = .center
    @State private var duration: Double = 60
    @State private var itemName: String = "Conference Schedule"
    @State private var transition: TransitionType = .dissolve
    @State private var transitionDuration: Double = 0.5
    
    // Custom colors
    @State private var useCustomColors: Bool = false
    @State private var customBackgroundColor: String = "#1A1A2E"
    @State private var customTextColor: String = "#FFFFFF"
    @State private var customAccentColor: String = "#FFD700"
    
    // UI state
    @State private var showPreview: Bool = false
    @State private var showAddEvent: Bool = false
    @State private var editingEvent: ScheduleEventItem?
    
    // Brand settings
    @ObservedObject private var brandManager = BrandSettingsManager.shared
    
    private var isEditing: Bool { editingIndex != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Events
                Section {
                    if events.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                Text("No events yet")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(events) { event in
                            ScheduleEventRow(event: event)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingEvent = event
                                }
                        }
                        .onDelete { indexSet in
                            events.remove(atOffsets: indexSet)
                        }
                        .onMove { from, to in
                            events.move(fromOffsets: from, toOffset: to)
                        }
                    }
                    
                    Button {
                        showAddEvent = true
                    } label: {
                        Label("Add Event", systemImage: "plus.circle.fill")
                    }
                } header: {
                    HStack {
                        Label("Events", systemImage: "calendar")
                        Spacer()
                        Text("\(events.count) events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - Display Options
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Seconds Per Event")
                            Spacer()
                            Text("\(Int(secondsPerEvent))s")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $secondsPerEvent, in: 3...20, step: 1)
                    }
                    
                    Picker("Text Alignment", selection: $alignment) {
                        ForEach(ScheduleAlignment.allCases, id: \.self) { align in
                            Text(align.displayName).tag(align)
                        }
                    }
                } header: {
                    Label("Display Options", systemImage: "slider.horizontal.3")
                } footer: {
                    Text("Events will rotate automatically, showing each for \(Int(secondsPerEvent)) seconds.")
                }
                
                // MARK: - Appearance
                Section {
                    Toggle("Use Custom Colors", isOn: $useCustomColors)
                    
                    if useCustomColors {
                        ColorPickerRow(label: "Background", hexColor: $customBackgroundColor)
                        ColorPickerRow(label: "Text", hexColor: $customTextColor)
                        ColorPickerRow(label: "Accent", hexColor: $customAccentColor)
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
                            Text("Total Duration")
                            Spacer()
                            Text(formatDuration(duration))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $duration, in: 10...300, step: 10)
                    }
                    
                    TextField("Item name in playlist", text: $itemName)
                } header: {
                    Label("Settings", systemImage: "gearshape")
                } footer: {
                    if !events.isEmpty {
                        let cycles = Int(duration / (secondsPerEvent * Double(events.count)))
                        Text("Will cycle through all \(events.count) events approximately \(max(1, cycles)) time\(cycles == 1 ? "" : "s").")
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
                
                // MARK: - Preview
                Section {
                    Button {
                        showPreview = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Preview Schedule", systemImage: "eye")
                            Spacer()
                        }
                    }
                    .disabled(events.isEmpty)
                    
                    // Mini preview
                    if let firstEvent = events.first {
                        ScheduleMiniPreview(
                            event: firstEvent,
                            alignment: alignment,
                            brandSettings: brandManager.settings,
                            useCustomColors: useCustomColors,
                            customBackgroundColor: customBackgroundColor,
                            customTextColor: customTextColor,
                            customAccentColor: customAccentColor
                        )
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets())
                    }
                } header: {
                    Label("Preview", systemImage: "rectangle.on.rectangle")
                }
            }
            .navigationTitle(isEditing ? "Edit Schedule" : "Schedule")
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
                    .disabled(events.isEmpty)
                }
            }
            .onAppear {
                setupDefaults()
                loadExistingData()
            }
            .sheet(isPresented: $showAddEvent) {
                AddScheduleEventSheet(events: $events)
            }
            .sheet(item: $editingEvent) { event in
                EditScheduleEventSheet(event: event, events: $events)
            }
            .sheet(isPresented: $showPreview) {
                ScheduleFullPreview(
                    events: events,
                    secondsPerEvent: secondsPerEvent,
                    alignment: alignment,
                    brandSettings: brandManager.settings,
                    useCustomColors: useCustomColors,
                    customBackgroundColor: customBackgroundColor,
                    customTextColor: customTextColor,
                    customAccentColor: customAccentColor
                )
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 && secs > 0 {
            return "\(mins)m \(secs)s"
        } else if mins > 0 {
            return "\(mins) min"
        } else {
            return "\(secs)s"
        }
    }
    
    private func setupDefaults() {
        customBackgroundColor = brandManager.settings.backgroundColor
        customTextColor = brandManager.settings.textColor
        customAccentColor = brandManager.settings.accentColor
    }
    
    private func loadExistingData() {
        if let data = existingData {
            // Convert ScheduleEvent to ScheduleEventItem
            events = data.events.map { event in
                ScheduleEventItem(
                    id: event.id,
                    title: event.title,
                    presenters: event.speaker ?? "",
                    time: event.time,
                    day: event.description ?? "",
                    location: event.location ?? ""
                )
            }
            useCustomColors = !data.usesBrandColors
            if let bg = data.customBackgroundColor { customBackgroundColor = bg }
            if let text = data.customTextColor { customTextColor = text }
            if let accent = data.customAccentColor { customAccentColor = accent }
            
            // Parse settings from subtitle
            if let subtitle = data.subtitle, subtitle.hasPrefix("{") {
                let trimmed = subtitle.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                let parts = trimmed.split(separator: ",")
                if parts.count >= 1, let secs = Double(parts[0]) {
                    secondsPerEvent = secs
                }
                if parts.count >= 2 {
                    alignment = String(parts[1]) == "left" ? .left : .center
                }
            }
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
        let scheduleEvents = events.map { item in
            ScheduleEvent(
                id: item.id,
                time: item.time,
                title: item.title,
                location: item.location.isEmpty ? nil : item.location,
                speaker: item.presenters.isEmpty ? nil : item.presenters,
                description: item.day.isEmpty ? nil : item.day
            )
        }
        
        var data = ScheduleData(
            title: "",
            events: scheduleEvents,
            displayMode: .rotating,
            rotationInterval: secondsPerEvent,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil,
            customAccentColor: useCustomColors ? customAccentColor : nil
        )
        
        // Store settings in subtitle
        data.subtitle = "{\(Int(secondsPerEvent)),\(alignment.rawValue)}"
        
        let item = PlaylistItem(
            name: itemName,
            contentType: .schedule(data: data),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
        
        playlistManager.addItem(item)
        playlistManager.savePlaylist()
    }
    
    private func updateItem() {
        guard let index = editingIndex else { return }
        
        let scheduleEvents = events.map { item in
            ScheduleEvent(
                id: item.id,
                time: item.time,
                title: item.title,
                location: item.location.isEmpty ? nil : item.location,
                speaker: item.presenters.isEmpty ? nil : item.presenters,
                description: item.day.isEmpty ? nil : item.day
            )
        }
        
        var data = ScheduleData(
            title: "",
            events: scheduleEvents,
            displayMode: .rotating,
            rotationInterval: secondsPerEvent,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil,
            customAccentColor: useCustomColors ? customAccentColor : nil
        )
        data.subtitle = "{\(Int(secondsPerEvent)),\(alignment.rawValue)}"
        
        playlistManager.items[index].name = itemName
        playlistManager.items[index].contentType = .schedule(data: data)
        playlistManager.items[index].duration = duration
        playlistManager.items[index].transition = transition
        playlistManager.items[index].transitionDuration = transitionDuration
        playlistManager.savePlaylist()
    }
}

// MARK: - Schedule Event Item

struct ScheduleEventItem: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var presenters: String
    var time: String
    var day: String
    var location: String
}

// MARK: - Event Row

struct ScheduleEventRow: View {
    let event: ScheduleEventItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.headline)
                .lineLimit(1)
            
            if !event.presenters.isEmpty {
                Text(event.presenters)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 12) {
                if !event.time.isEmpty {
                    Label(event.time, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !event.day.isEmpty {
                    Text(event.day)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Event Sheet

struct AddScheduleEventSheet: View {
    @Binding var events: [ScheduleEventItem]
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var presenters: String = ""
    @State private var time: String = ""
    @State private var day: String = ""
    @State private var location: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Session Title", text: $title)
                        .font(.headline)
                    
                    TextField("Presenter(s)", text: $presenters)
                } header: {
                    Text("Session Info")
                }
                
                Section {
                    TextField("Time (e.g., 2:30 - 3:30 p.m.)", text: $time)
                    
                    TextField("Day (e.g., Monday, January 21)", text: $day)
                    
                    TextField("Location (e.g., Room 405)", text: $location)
                } header: {
                    Text("When & Where")
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let event = ScheduleEventItem(
                            title: title,
                            presenters: presenters,
                            time: time,
                            day: day,
                            location: location
                        )
                        events.append(event)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Event Sheet

struct EditScheduleEventSheet: View {
    let event: ScheduleEventItem
    @Binding var events: [ScheduleEventItem]
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var presenters: String = ""
    @State private var time: String = ""
    @State private var day: String = ""
    @State private var location: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Session Title", text: $title)
                        .font(.headline)
                    
                    TextField("Presenter(s)", text: $presenters)
                } header: {
                    Text("Session Info")
                }
                
                Section {
                    TextField("Time (e.g., 2:30 - 3:30 p.m.)", text: $time)
                    
                    TextField("Day (e.g., Monday, January 21)", text: $day)
                    
                    TextField("Location (e.g., Room 405)", text: $location)
                } header: {
                    Text("When & Where")
                }
                
                Section {
                    Button(role: .destructive) {
                        events.removeAll { $0.id == event.id }
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Event")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let index = events.firstIndex(where: { $0.id == event.id }) {
                            events[index].title = title
                            events[index].presenters = presenters
                            events[index].time = time
                            events[index].day = day
                            events[index].location = location
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                title = event.title
                presenters = event.presenters
                time = event.time
                day = event.day
                location = event.location
            }
        }
    }
}

// MARK: - Mini Preview

struct ScheduleMiniPreview: View {
    let event: ScheduleEventItem
    let alignment: ScheduleAlignment
    let brandSettings: BrandSettings
    let useCustomColors: Bool
    let customBackgroundColor: String
    let customTextColor: String
    let customAccentColor: String
    
    private var bgColor: Color {
        useCustomColors ? Color(hex: customBackgroundColor) : brandSettings.backgroundSwiftUIColor
    }
    
    private var textColor: Color {
        useCustomColors ? Color(hex: customTextColor) : brandSettings.textSwiftUIColor
    }
    
    private var accentColor: Color {
        useCustomColors ? Color(hex: customAccentColor) : brandSettings.accentSwiftUIColor
    }
    
    private var frameAlignment: Alignment {
        alignment == .center ? .center : .leading
    }
    
    private var textAlignment: TextAlignment {
        alignment == .center ? .center : .leading
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Title - Bold, large
            Text(event.title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(textColor)
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
            
            // Presenters - Medium size
            if !event.presenters.isEmpty {
                Text(event.presenters)
                    .font(.subheadline)
                    .foregroundColor(textColor.opacity(0.9))
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            
            Spacer().frame(height: 12)
            
            // Time - Accent color, small caps
            if !event.time.isEmpty {
                Text(event.time.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundColor(accentColor)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            
            // Day - Small caps
            if !event.day.isEmpty {
                Text(event.day.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1.5)
                    .foregroundColor(textColor.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            
            // Location - Small caps
            if !event.location.isEmpty {
                Text(event.location.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1.5)
                    .foregroundColor(textColor.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
        .padding()
        .background(bgColor)
        .cornerRadius(12)
        .padding(8)
    }
}

// MARK: - Full Preview

struct ScheduleFullPreview: View {
    let events: [ScheduleEventItem]
    let secondsPerEvent: Double
    let alignment: ScheduleAlignment
    let brandSettings: BrandSettings
    let useCustomColors: Bool
    let customBackgroundColor: String
    let customTextColor: String
    let customAccentColor: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var timer: Timer?
    
    private var bgColor: Color {
        useCustomColors ? Color(hex: customBackgroundColor) : brandSettings.backgroundSwiftUIColor
    }
    
    private var textColor: Color {
        useCustomColors ? Color(hex: customTextColor) : brandSettings.textSwiftUIColor
    }
    
    private var accentColor: Color {
        useCustomColors ? Color(hex: customAccentColor) : brandSettings.accentSwiftUIColor
    }
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            // Event display
            if !events.isEmpty {
                ScheduleEventDisplay(
                    event: events[currentIndex],
                    alignment: alignment,
                    textColor: textColor,
                    accentColor: accentColor
                )
                .id(currentIndex)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        timer?.invalidate()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8), .black.opacity(0.3))
                    }
                    .padding()
                }
                Spacer()
                
                // Progress dots
                if events.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<events.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        guard events.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: secondsPerEvent, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = (currentIndex + 1) % events.count
            }
        }
    }
}

// MARK: - Schedule Event Display (Full Screen)

struct ScheduleEventDisplay: View {
    let event: ScheduleEventItem
    let alignment: ScheduleAlignment
    let textColor: Color
    let accentColor: Color
    
    private var frameAlignment: Alignment {
        alignment == .center ? .center : .leading
    }
    
    private var textAlignment: TextAlignment {
        alignment == .center ? .center : .leading
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title - Bold, large
            Text(event.title)
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(textColor)
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
            
            // Presenters - Medium size
            if !event.presenters.isEmpty {
                Text(event.presenters)
                    .font(.system(size: 36, weight: .regular))
                    .foregroundColor(textColor.opacity(0.9))
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            
            Spacer().frame(height: 30)
            
            // Time - Accent, all caps
            if !event.time.isEmpty {
                Text(event.time.uppercased())
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(accentColor)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            
            // Day - Small, all caps
            if !event.day.isEmpty {
                Text(event.day.uppercased())
                    .font(.system(size: 20, weight: .medium))
                    .tracking(3)
                    .foregroundColor(textColor.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            
            // Location - Small, all caps
            if !event.location.isEmpty {
                Text(event.location.uppercased())
                    .font(.system(size: 20, weight: .medium))
                    .tracking(3)
                    .foregroundColor(textColor.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }
}

// MARK: - Preview

#Preview {
    ScheduleEditorView(playlistManager: PlaylistManager(items: []))
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
