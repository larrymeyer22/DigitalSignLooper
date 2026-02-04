//
//  WeatherEditorView.swift
//  DigitalSignLooper
//
//  Form for creating and editing Weather display content
//  Requires: WeatherKit capability + CoreLocation
//

import SwiftUI
import CoreLocation

struct WeatherEditorView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.dismiss) private var dismiss
    
    // Edit mode
    var editingIndex: Int?
    var existingData: WeatherData?
    
    // Form state
    @State private var locationName: String = ""
    @State private var latitude: Double = 29.7604
    @State private var longitude: Double = -98.4936
    @State private var showForecast: Bool = true
    @State private var forecastDays: Int = 5
    @State private var temperatureUnit: TemperatureUnit = .fahrenheit
    @State private var duration: Double = 15
    @State private var itemName: String = ""
    
    // Custom colors
    @State private var useCustomColors: Bool = false
    @State private var customBackgroundColor: String = "#1A1A2E"
    @State private var customTextColor: String = "#FFFFFF"
    @State private var customAccentColor: String = "#4A90D9"
    
    // Transition
    @State private var transition: TransitionType = .dissolve
    @State private var transitionDuration: Double = 0.5
    
    // Location search
    @State private var searchText: String = ""
    @State private var searchResults: [CLPlacemark] = []
    @State private var isSearching: Bool = false
    @State private var locationConfirmed: Bool = false
    
    // Weather preview
    @State private var previewWeather: FetchedWeather?
    @State private var isLoadingWeather: Bool = false
    
    @ObservedObject private var brandManager = BrandSettingsManager.shared
    
    private var isEditing: Bool { editingIndex != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Location
                Section {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search city or zip code", text: $searchText)
                            .textInputAutocapitalization(.words)
                            .onSubmit {
                                searchLocation()
                            }
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Search results
                    if !searchResults.isEmpty {
                        ForEach(searchResults, id: \.self) { placemark in
                            Button {
                                selectLocation(placemark)
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.red)
                                    VStack(alignment: .leading) {
                                        Text(placemark.locality ?? placemark.name ?? "Unknown")
                                            .foregroundColor(.primary)
                                        if let state = placemark.administrativeArea, let country = placemark.isoCountryCode {
                                            Text("\(state), \(country)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    
                    // Selected location display
                    if locationConfirmed && !locationName.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text(locationName)
                                    .fontWeight(.medium)
                                Text(String(format: "%.4f, %.4f", latitude, longitude))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("Location", systemImage: "mappin.and.ellipse")
                } footer: {
                    Text("Enter a city name or zip code, then select from the results.")
                }
                
                // MARK: - Display Options
                Section {
                    Picker("Temperature", selection: $temperatureUnit) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Show Forecast", isOn: $showForecast)
                    
                    if showForecast {
                        Stepper("Forecast Days: \(forecastDays)", value: $forecastDays, in: 3...7)
                    }
                } header: {
                    Label("Display", systemImage: "rectangle.3.group")
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
                if locationConfirmed {
                    Section {
                        if isLoadingWeather {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text("Fetching weather...")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else if let weather = previewWeather {
                            // Mini preview
                            WeatherMiniPreview(
                                data: currentWeatherData,
                                weather: weather,
                                brandSettings: brandManager.settings
                            )
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets())
                        }
                        
                        Button {
                            fetchWeatherPreview()
                        } label: {
                            HStack {
                                Spacer()
                                Label(previewWeather == nil ? "Load Preview" : "Refresh Preview", systemImage: "arrow.clockwise")
                                Spacer()
                            }
                        }
                    } header: {
                        Label("Preview", systemImage: "eye")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Weather" : "Weather Display")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                    .disabled(locationName.isEmpty || !locationConfirmed)
                }
            }
            .onAppear {
                customBackgroundColor = brandManager.settings.backgroundColor
                customTextColor = brandManager.settings.textColor
                customAccentColor = brandManager.settings.accentColor
                
                if let data = existingData {
                    locationName = data.locationName
                    latitude = data.latitude
                    longitude = data.longitude
                    showForecast = data.showForecast
                    forecastDays = data.forecastDays
                    temperatureUnit = data.temperatureUnit
                    useCustomColors = !data.usesBrandColors
                    locationConfirmed = true
                    
                    if let bg = data.customBackgroundColor { customBackgroundColor = bg }
                    if let text = data.customTextColor { customTextColor = text }
                    if let accent = data.customAccentColor { customAccentColor = accent }
                    
                    // Auto-fetch preview for existing items
                    fetchWeatherPreview()
                }
                
                if let index = editingIndex, index < playlistManager.items.count {
                    let item = playlistManager.items[index]
                    itemName = item.name
                    duration = item.duration
                    transition = item.transition.normalized
                    transitionDuration = item.transitionDuration
                }
            }
        }
    }
    
    // MARK: - Computed
    
    private var currentWeatherData: WeatherData {
        WeatherData(
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            showForecast: showForecast,
            forecastDays: forecastDays,
            temperatureUnit: temperatureUnit,
            usesBrandColors: !useCustomColors,
            customBackgroundColor: useCustomColors ? customBackgroundColor : nil,
            customTextColor: useCustomColors ? customTextColor : nil,
            customAccentColor: useCustomColors ? customAccentColor : nil
        )
    }
    
    // MARK: - Location Search
    
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchText) { placemarks, error in
            DispatchQueue.main.async {
                isSearching = false
                if let placemarks = placemarks, !placemarks.isEmpty {
                    searchResults = Array(placemarks.prefix(5))
                } else {
                    searchResults = []
                }
            }
        }
    }
    
    private func selectLocation(_ placemark: CLPlacemark) {
        if let location = placemark.location {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
        }
        
        // Build a nice display name
        var parts: [String] = []
        if let city = placemark.locality { parts.append(city) }
        if let state = placemark.administrativeArea { parts.append(state) }
        locationName = parts.joined(separator: ", ")
        
        if locationName.isEmpty {
            locationName = placemark.name ?? "Unknown Location"
        }
        
        locationConfirmed = true
        searchResults = []
        searchText = ""
        
        // Auto-fetch preview
        fetchWeatherPreview()
    }
    
    // MARK: - Weather Fetch
    
    private func fetchWeatherPreview() {
        isLoadingWeather = true
        Task {
            let result = await WeatherFetcher.shared.fetchWeather(
                latitude: latitude,
                longitude: longitude,
                days: forecastDays
            )
            await MainActor.run {
                previewWeather = result
                isLoadingWeather = false
            }
        }
    }
    
    // MARK: - Actions
    
    private func addToPlaylist() {
        let name = itemName.isEmpty ? "Weather – \(locationName)" : itemName
        let data = currentWeatherData
        
        let item = PlaylistItem(
            name: name,
            contentType: .weather(data: data),
            duration: duration,
            transition: transition,
            transitionDuration: transitionDuration
        )
        
        playlistManager.addItem(item)
        playlistManager.savePlaylist()
    }
    
    private func updateItem() {
        guard let index = editingIndex else { return }
        let name = itemName.isEmpty ? "Weather – \(locationName)" : itemName
        let data = currentWeatherData
        
        playlistManager.items[index].name = name
        playlistManager.items[index].contentType = .weather(data: data)
        playlistManager.items[index].duration = duration
        playlistManager.items[index].transition = transition
        playlistManager.items[index].transitionDuration = transitionDuration
        playlistManager.savePlaylist()
    }
}

// MARK: - Weather Mini Preview

struct WeatherMiniPreview: View {
    let data: WeatherData
    let weather: FetchedWeather
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
            Text(data.locationName)
                .font(.caption)
                .foregroundColor(textColor.opacity(0.7))
            
            HStack(spacing: 12) {
                Image(systemName: weather.current.symbolName)
                    .font(.largeTitle)
                    .symbolRenderingMode(.multicolor)
                
                Text("\(weather.current.temperature(in: data.temperatureUnit))°")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(textColor)
            }
            
            Text(weather.current.conditionDescription)
                .font(.subheadline)
                .foregroundColor(textColor.opacity(0.8))
            
            if data.showForecast {
                HStack(spacing: 12) {
                    ForEach(Array(weather.dailyForecast.prefix(data.forecastDays).enumerated()), id: \.offset) { index, day in
                        VStack(spacing: 2) {
                            Text(index == 0 ? "Today" : dayAbbrev(day.date))
                                .font(.caption2)
                                .foregroundColor(textColor.opacity(0.6))
                            Image(systemName: day.symbolName)
                                .font(.caption)
                                .symbolRenderingMode(.multicolor)
                            Text("\(day.high(in: data.temperatureUnit))°")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(textColor)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(bgColor)
        .cornerRadius(12)
        .padding(8)
    }
    
    private func dayAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
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
