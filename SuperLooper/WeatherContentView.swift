//
//  WeatherContentView.swift
//  DigitalSignLooper
//
//  Live weather display view that auto-fetches and renders weather data
//  Used by both ContentDisplayView and ExternalScreenView
//

import SwiftUI

struct WeatherContentView: View {
    let data: WeatherData
    let brandSettings: BrandSettings
    
    @State private var fetchedWeather: FetchedWeather?
    @State private var isLoading: Bool = true
    
    var body: some View {
        TemplateHTMLView(html: currentHTML)
            .onAppear {
                fetchWeather()
            }
    }
    
    private var currentHTML: String {
        if let weather = fetchedWeather {
            return WeatherRenderer.render(
                data: data,
                weather: weather,
                brandSettings: brandSettings
            )
        } else {
            return WeatherRenderer.renderLoading(
                data: data,
                brandSettings: brandSettings
            )
        }
    }
    
    private func fetchWeather() {
        // Check cache first
        if let cached = WeatherFetcher.shared.getCached(latitude: data.latitude, longitude: data.longitude) {
            fetchedWeather = cached
            isLoading = false
            return
        }
        
        Task {
            let result = await WeatherFetcher.shared.fetchWeather(
                latitude: data.latitude,
                longitude: data.longitude,
                days: data.forecastDays
            )
            await MainActor.run {
                fetchedWeather = result
                isLoading = false
            }
        }
    }
}
