//
//  WeatherRenderer.swift
//  DigitalSignLooper
//
//  Renders weather data as HTML for display on digital signs
//

import Foundation

struct WeatherRenderer {
    
    /// Render weather HTML from fetched data + configuration
    static func render(
        data: WeatherData,
        weather: FetchedWeather,
        brandSettings: BrandSettings
    ) -> String {
        let bgColor: String
        let textColor: String
        let accentColor: String
        
        if data.usesBrandColors {
            bgColor = brandSettings.backgroundColor
            textColor = brandSettings.textColor
            accentColor = brandSettings.accentColor
        } else {
            bgColor = data.customBackgroundColor ?? brandSettings.backgroundColor
            textColor = data.customTextColor ?? brandSettings.textColor
            accentColor = data.customAccentColor ?? brandSettings.accentColor
        }
        
        let titleFont = brandSettings.titleFontCSS
        let bodyFont = brandSettings.bodyFontCSS
        let titleWeight = brandSettings.titleFontWeight.cssValue
        let bodyWeight = brandSettings.bodyFontWeight.cssValue
        
        let unit = data.temperatureUnit
        let current = weather.current
        let temp = current.temperature(in: unit)
        let feelsLike = current.feelsLike(in: unit)
        let unitLabel = unit.rawValue
        
        // Map SF Symbol name to a weather emoji for HTML (since we can't use SF Symbols in HTML)
        let weatherEmoji = symbolToEmoji(current.symbolName)
        
        // Build forecast HTML
        var forecastHTML = ""
        if data.showForecast {
            let days = Array(weather.dailyForecast.prefix(data.forecastDays))
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            
            for (index, day) in days.enumerated() {
                let dayName = index == 0 ? "Today" : dayFormatter.string(from: day.date)
                let emoji = symbolToEmoji(day.symbolName)
                let hi = day.high(in: unit)
                let lo = day.low(in: unit)
                let precip = Int(day.precipitationChance)
                
                forecastHTML += """
                <div class="forecast-day" style="animation-delay: \(Double(index) * 0.1)s">
                    <div class="day-name">\(escapeHTML(dayName))</div>
                    <div class="day-icon">\(emoji)</div>
                    <div class="day-temps">
                        <span class="day-hi">\(hi)°</span>
                        <span class="day-lo">\(lo)°</span>
                    </div>
                    \(precip > 20 ? "<div class=\"day-precip\">💧\(precip)%</div>" : "")
                </div>
                """
            }
        }
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                
                body {
                    background: \(bgColor);
                    color: \(textColor);
                    font-family: \(bodyFont);
                    height: 100vh;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    padding: 4%;
                    overflow: hidden;
                }
                
                .weather-container {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 3vh;
                    width: 100%;
                    max-width: 90%;
                }
                
                /* Location */
                .location {
                    font-family: \(titleFont);
                    font-size: 3.5vw;
                    font-weight: \(bodyWeight);
                    opacity: 0.7;
                    letter-spacing: 0.05em;
                    text-transform: uppercase;
                    animation: fadeIn 0.8s ease-out;
                }
                
                /* Current conditions - big hero area */
                .current {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    gap: 4vw;
                    animation: fadeIn 0.6s ease-out;
                }
                
                .current-icon {
                    font-size: 12vw;
                    line-height: 1;
                    filter: drop-shadow(0 0.5vh 1vh rgba(0,0,0,0.2));
                }
                
                .current-temp {
                    font-family: \(titleFont);
                    font-size: 14vw;
                    font-weight: \(titleWeight);
                    line-height: 1;
                    letter-spacing: -0.02em;
                }
                
                .current-unit {
                    font-size: 5vw;
                    font-weight: \(bodyWeight);
                    opacity: 0.5;
                    vertical-align: super;
                }
                
                /* Condition description */
                .condition {
                    font-family: \(titleFont);
                    font-size: 3.5vw;
                    font-weight: \(bodyWeight);
                    opacity: 0.85;
                    animation: fadeIn 1s ease-out;
                }
                
                /* Details row */
                .details {
                    display: flex;
                    gap: 4vw;
                    font-size: 2.2vw;
                    opacity: 0.6;
                    animation: fadeIn 1.2s ease-out;
                }
                
                .detail-item {
                    display: flex;
                    align-items: center;
                    gap: 0.5vw;
                }
                
                /* Forecast strip */
                .forecast {
                    display: flex;
                    justify-content: center;
                    gap: 2.5vw;
                    margin-top: 2vh;
                    padding-top: 3vh;
                    border-top: 1px solid \(textColor)22;
                    width: 100%;
                }
                
                .forecast-day {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 1vh;
                    min-width: 8vw;
                    animation: slideUp 0.6s ease-out both;
                }
                
                .day-name {
                    font-family: \(titleFont);
                    font-size: 1.8vw;
                    font-weight: \(titleWeight);
                    text-transform: uppercase;
                    letter-spacing: 0.05em;
                    opacity: 0.7;
                }
                
                .day-icon {
                    font-size: 3.5vw;
                }
                
                .day-temps {
                    display: flex;
                    gap: 0.8vw;
                    font-size: 2vw;
                }
                
                .day-hi {
                    font-weight: \(titleWeight);
                }
                
                .day-lo {
                    opacity: 0.5;
                }
                
                .day-precip {
                    font-size: 1.5vw;
                    opacity: 0.6;
                }
                
                /* Attribution */
                .attribution {
                    position: fixed;
                    bottom: 1.5vh;
                    right: 2vw;
                    font-size: 1.2vw;
                    opacity: 0.3;
                }
                
                /* Animations */
                @keyframes fadeIn {
                    from { opacity: 0; transform: translateY(-1vh); }
                    to { opacity: 1; transform: translateY(0); }
                }
                
                @keyframes slideUp {
                    from { opacity: 0; transform: translateY(2vh); }
                    to { opacity: 1; transform: translateY(0); }
                }
            </style>
        </head>
        <body>
            <div class="weather-container">
                <div class="location">\(escapeHTML(data.locationName))</div>
                
                <div class="current">
                    <div class="current-icon">\(weatherEmoji)</div>
                    <div class="current-temp">
                        \(temp)<span class="current-unit">\(unitLabel)</span>
                    </div>
                </div>
                
                <div class="condition">\(escapeHTML(current.conditionDescription))</div>
                
                <div class="details">
                    <div class="detail-item">🌡 Feels like \(feelsLike)\(unitLabel)</div>
                    <div class="detail-item">💧 \(Int(current.humidity))%</div>
                    <div class="detail-item">💨 \(Int(current.windSpeed)) km/h</div>
                    <div class="detail-item">☀️ UV \(current.uvIndex)</div>
                </div>
                
                \(data.showForecast ? "<div class=\"forecast\">\(forecastHTML)</div>" : "")
            </div>
            
            <div class="attribution"> Weather</div>
        </body>
        </html>
        """
        
        return html
    }
    
    /// Render a loading/placeholder HTML when weather hasn't loaded yet
    static func renderLoading(data: WeatherData, brandSettings: BrandSettings) -> String {
        let bgColor = data.usesBrandColors ? brandSettings.backgroundColor : (data.customBackgroundColor ?? brandSettings.backgroundColor)
        let textColor = data.usesBrandColors ? brandSettings.textColor : (data.customTextColor ?? brandSettings.textColor)
        let titleFont = brandSettings.titleFontCSS
        let bodyFont = brandSettings.bodyFontCSS
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background: \(bgColor);
                    color: \(textColor);
                    font-family: \(bodyFont);
                    height: 100vh;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    gap: 3vh;
                }
                .icon { font-size: 10vw; animation: pulse 2s ease-in-out infinite; }
                .text { font-family: \(titleFont); font-size: 3vw; opacity: 0.6; }
                .location { font-size: 2.5vw; opacity: 0.4; }
                @keyframes pulse {
                    0%, 100% { opacity: 0.4; }
                    50% { opacity: 1; }
                }
            </style>
        </head>
        <body>
            <div class="icon">🌤</div>
            <div class="text">Loading Weather...</div>
            <div class="location">\(escapeHTML(data.locationName))</div>
        </body>
        </html>
        """
    }
    
    // MARK: - Helpers
    
    /// Map WeatherKit SF Symbol names to emoji for HTML display
    private static func symbolToEmoji(_ symbolName: String) -> String {
        // WeatherKit symbol names follow a pattern
        let name = symbolName.lowercased()
        
        if name.contains("snow") || name.contains("sleet") || name.contains("ice") {
            return "❄️"
        } else if name.contains("thunderstorm") || name.contains("tropicalstorm") {
            return "⛈"
        } else if name.contains("rain") || name.contains("drizzle") || name.contains("shower") {
            return "🌧"
        } else if name.contains("fog") || name.contains("haze") || name.contains("smoke") {
            return "🌫"
        } else if name.contains("wind") || name.contains("breezy") {
            return "💨"
        } else if name.contains("cloudy") && name.contains("sun") {
            return "⛅"
        } else if name.contains("cloud.sun") || name.contains("partly") {
            return "🌤"
        } else if name.contains("cloudy") || name.contains("cloud") {
            return "☁️"
        } else if name.contains("sun.max") || name.contains("clear") {
            if name.contains("night") || name.contains("moon") {
                return "🌙"
            }
            return "☀️"
        } else if name.contains("moon") || name.contains("night") || name.contains("star") {
            return "🌙"
        } else if name.contains("hot") || name.contains("thermometer.sun") {
            return "🌡"
        }
        
        return "🌤" // Default
    }
    
    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
