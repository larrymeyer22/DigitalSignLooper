//
//  WeatherService+App.swift
//  DigitalSignLooper
//
//  Wrapper around Apple WeatherKit for fetching weather data
//  Requires: WeatherKit capability enabled in Xcode + Developer Portal
//

import Foundation
import Combine
import WeatherKit
import CoreLocation

// MARK: - Weather Fetcher

/// Singleton service for fetching weather data via Apple WeatherKit
class WeatherFetcher: ObservableObject {
    static let shared = WeatherFetcher()
    
    private let service = WeatherService.shared
    
    /// Cached weather results keyed by "lat,lon"
    @Published var cachedResults: [String: FetchedWeather] = [:]
    
    /// Fetch current weather + daily forecast for a location
    func fetchWeather(latitude: Double, longitude: Double, days: Int = 5) async -> FetchedWeather? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            let weather = try await service.weather(for: location)
            
            let current = FetchedCurrentWeather(
                temperature: weather.currentWeather.temperature.value,
                apparentTemperature: weather.currentWeather.apparentTemperature.value,
                conditionDescription: weather.currentWeather.condition.description,
                symbolName: weather.currentWeather.symbolName,
                humidity: weather.currentWeather.humidity * 100,
                windSpeed: weather.currentWeather.wind.speed.value,
                uvIndex: weather.currentWeather.uvIndex.value
            )
            
            let forecast = weather.dailyForecast.prefix(days).map { day in
                FetchedDayForecast(
                    date: day.date,
                    highTemperature: day.highTemperature.value,
                    lowTemperature: day.lowTemperature.value,
                    conditionDescription: day.condition.description,
                    symbolName: day.symbolName,
                    precipitationChance: day.precipitationChance * 100
                )
            }
            
            let result = FetchedWeather(
                current: current,
                dailyForecast: Array(forecast),
                fetchedAt: Date()
            )
            
            let key = "\(latitude),\(longitude)"
            await MainActor.run {
                self.cachedResults[key] = result
            }
            
            return result
        } catch {
            print("WeatherKit error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get cached result if fresh enough (< 10 minutes old)
    func getCached(latitude: Double, longitude: Double) -> FetchedWeather? {
        let key = "\(latitude),\(longitude)"
        guard let cached = cachedResults[key] else { return nil }
        if Date().timeIntervalSince(cached.fetchedAt) < 600 { // 10 min
            return cached
        }
        return nil
    }
}

// MARK: - Fetched Weather Models (Codable for caching)

struct FetchedWeather: Codable, Equatable {
    let current: FetchedCurrentWeather
    let dailyForecast: [FetchedDayForecast]
    let fetchedAt: Date
}

struct FetchedCurrentWeather: Codable, Equatable {
    let temperature: Double          // In Celsius from WeatherKit
    let apparentTemperature: Double
    let conditionDescription: String // e.g., "Partly Cloudy"
    let symbolName: String           // SF Symbol name
    let humidity: Double             // 0-100
    let windSpeed: Double            // km/h
    let uvIndex: Int
}

struct FetchedDayForecast: Codable, Equatable {
    let date: Date
    let highTemperature: Double      // Celsius
    let lowTemperature: Double       // Celsius
    let conditionDescription: String
    let symbolName: String
    let precipitationChance: Double  // 0-100
}

// MARK: - Temperature Conversion

extension FetchedCurrentWeather {
    func temperature(in unit: TemperatureUnit) -> Int {
        switch unit {
        case .fahrenheit:
            return Int(round(temperature * 9.0 / 5.0 + 32))
        case .celsius:
            return Int(round(temperature))
        }
    }
    
    func feelsLike(in unit: TemperatureUnit) -> Int {
        switch unit {
        case .fahrenheit:
            return Int(round(apparentTemperature * 9.0 / 5.0 + 32))
        case .celsius:
            return Int(round(apparentTemperature))
        }
    }
}

extension FetchedDayForecast {
    func high(in unit: TemperatureUnit) -> Int {
        switch unit {
        case .fahrenheit:
            return Int(round(highTemperature * 9.0 / 5.0 + 32))
        case .celsius:
            return Int(round(highTemperature))
        }
    }
    
    func low(in unit: TemperatureUnit) -> Int {
        switch unit {
        case .fahrenheit:
            return Int(round(lowTemperature * 9.0 / 5.0 + 32))
        case .celsius:
            return Int(round(lowTemperature))
        }
    }
}
