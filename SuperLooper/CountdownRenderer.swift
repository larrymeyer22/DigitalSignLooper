//
//  CountdownRenderer.swift
//  Super Looper
//
//  Renders countdown timer as HTML with live JavaScript countdown
//

import Foundation

enum CountdownRenderer {
    
    /// Render countdown timer as HTML
    static func render(data: CountdownData, brandSettings: BrandSettings) -> String {
        // Determine colors
        let bgColor = data.usesBrandColors ? brandSettings.backgroundColor : (data.customBackgroundColor ?? "#000000")
        let textColor = data.usesBrandColors ? brandSettings.textColor : (data.customTextColor ?? "#FFFFFF")
        let accentColor = data.usesBrandColors ? brandSettings.accentColor : (data.customAccentColor ?? "#007AFF")
        
        // Font
        let fontFamily = brandSettings.bodyFontCSS
        
        // Calculate target time or duration
        let countdownScript: String
        if data.mode == .targetTime, let targetDate = data.targetDate {
            let timestamp = Int(targetDate.timeIntervalSince1970 * 1000)
            countdownScript = """
                const targetTime = \(timestamp);
                const isTargetMode = true;
            """
        } else {
            let totalSeconds = data.totalDurationSeconds
            countdownScript = """
                const durationSeconds = \(totalSeconds);
                const isTargetMode = false;
                let remainingSeconds = durationSeconds;
            """
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                html, body {
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                    background-color: \(bgColor);
                    font-family: \(fontFamily);
                }
                
                .container {
                    width: 100%;
                    height: 100%;
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                    padding: 5%;
                }
                
                .title {
                    font-size: 4vw;
                    font-weight: 600;
                    color: \(textColor);
                    opacity: 0.85;
                    margin-bottom: 3vh;
                    text-align: center;
                    text-transform: uppercase;
                    letter-spacing: 0.15em;
                }
                
                .timer-container {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    gap: 2vw;
                }
                
                .time-block {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                }
                
                .time-value {
                    font-size: 15vw;
                    font-weight: 700;
                    color: \(textColor);
                    line-height: 1;
                    font-variant-numeric: tabular-nums;
                }
                
                .time-label {
                    font-size: 2vw;
                    font-weight: 500;
                    color: \(textColor);
                    opacity: 0.6;
                    text-transform: uppercase;
                    letter-spacing: 0.2em;
                    margin-top: 1vh;
                }
                
                .hide-labels .time-label {
                    display: none !important;
                }
                
                .hide-labels .separator {
                    margin-bottom: 0;
                }
                
                .hide-labels .time-value {
                    font-size: 20vw;
                }
                
                .hide-labels .separator {
                    font-size: 16vw;
                }
                
                .separator {
                    font-size: 12vw;
                    font-weight: 700;
                    color: \(accentColor);
                    line-height: 1;
                    margin-bottom: 4vh;
                }
                
                .expired-message {
                    font-size: 10vw;
                    font-weight: 700;
                    color: \(accentColor);
                    text-align: center;
                    animation: pulse 1.5s ease-in-out infinite;
                }
                
                @keyframes pulse {
                    0%, 100% { opacity: 1; transform: scale(1); }
                    50% { opacity: 0.8; transform: scale(1.02); }
                }
                
                .hidden {
                    display: none !important;
                }
                
                /* Responsive adjustments */
                @media (max-aspect-ratio: 4/3) {
                    .time-value {
                        font-size: 12vw;
                    }
                    .separator {
                        font-size: 10vw;
                    }
                    .title {
                        font-size: 5vw;
                    }
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="title \(data.title == nil || data.title!.isEmpty ? "hidden" : "")" id="title">\(data.title ?? "")</div>
                
                <div class="timer-container \(data.showHours || data.showDays ? "" : "hide-labels")" id="timerContainer">
                    <div class="time-block \(data.showDays ? "" : "hidden")" id="daysBlock">
                        <div class="time-value" id="days">00</div>
                        <div class="time-label">Days</div>
                    </div>
                    <div class="separator \(data.showDays ? "" : "hidden")" id="daysSep">:</div>
                    
                    <div class="time-block \(data.showHours ? "" : "hidden")" id="hoursBlock">
                        <div class="time-value" id="hours">00</div>
                        <div class="time-label">Hours</div>
                    </div>
                    <div class="separator \(data.showHours ? "" : "hidden")" id="hoursSep">:</div>
                    
                    <div class="time-block">
                        <div class="time-value" id="minutes">00</div>
                        <div class="time-label">Minutes</div>
                    </div>
                    <div class="separator">:</div>
                    
                    <div class="time-block">
                        <div class="time-value" id="seconds">00</div>
                        <div class="time-label">Seconds</div>
                    </div>
                </div>
                
                <div class="expired-message hidden" id="expiredMessage">\(escapeHTML(data.expiredMessage))</div>
            </div>
            
            <script>
                \(countdownScript)
                const showDays = \(data.showDays ? "true" : "false");
                const showHours = \(data.showHours ? "true" : "false");
                
                const daysEl = document.getElementById('days');
                const hoursEl = document.getElementById('hours');
                const minutesEl = document.getElementById('minutes');
                const secondsEl = document.getElementById('seconds');
                const timerContainer = document.getElementById('timerContainer');
                const expiredMessage = document.getElementById('expiredMessage');
                
                function pad(num) {
                    return num.toString().padStart(2, '0');
                }
                
                function updateDisplay(totalSeconds) {
                    if (totalSeconds <= 0) {
                        timerContainer.classList.add('hidden');
                        expiredMessage.classList.remove('hidden');
                        return false;
                    }
                    
                    const days = Math.floor(totalSeconds / 86400);
                    const hours = Math.floor((totalSeconds % 86400) / 3600);
                    const minutes = Math.floor((totalSeconds % 3600) / 60);
                    const seconds = totalSeconds % 60;
                    
                    if (showDays) {
                        daysEl.textContent = pad(days);
                        hoursEl.textContent = pad(hours);
                    } else if (showHours) {
                        // Roll days into hours
                        hoursEl.textContent = pad(days * 24 + hours);
                    }
                    
                    // Calculate total minutes for display
                    let displayMinutes = minutes;
                    if (!showHours) {
                        // Roll hours into minutes
                        displayMinutes = (days * 24 + hours) * 60 + minutes;
                    }
                    
                    // Drop leading zero if less than 10 minutes and hours not shown
                    if (!showHours && displayMinutes < 10) {
                        minutesEl.textContent = displayMinutes.toString();
                    } else {
                        minutesEl.textContent = pad(displayMinutes);
                    }
                    
                    secondsEl.textContent = pad(seconds);
                    
                    return true;
                }
                
                function tick() {
                    let totalSeconds;
                    
                    if (isTargetMode) {
                        const now = Date.now();
                        totalSeconds = Math.floor((targetTime - now) / 1000);
                    } else {
                        totalSeconds = remainingSeconds;
                        remainingSeconds--;
                    }
                    
                    if (!updateDisplay(totalSeconds)) {
                        clearInterval(interval);
                    }
                }
                
                // Initial update
                tick();
                
                // Update every second
                const interval = setInterval(tick, 1000);
            </script>
        </body>
        </html>
        """
    }
    
    /// Escape HTML special characters
    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
