//
//  LeaderboardRenderer.swift
//  Super Looper
//
//  Renders Leaderboard data to HTML with bottom-to-top reveal animation
//

import Foundation

enum LeaderboardRenderer {
    static func render(data: LeaderboardData, brandSettings: BrandSettings) -> String {
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
        
        let ranked = data.rankedEntries
        let total = ranked.count
        var entriesHTML = ""
        
        for (index, entry) in ranked.enumerated() {
            let rank = index + 1
            
            // Bottom-to-top: last place reveals first, #1 reveals last
            let revealOrder = total - 1 - index
            let delay = Double(revealOrder) * 0.3 + 0.5
            
            var entryHTML = """
            <div class="entry" style="--delay: \(delay)s;">
                <div class="rank-number">\(rank)</div>
                <div class="name">\(escapeHTML(entry.name))</div>
            """
            
            if data.showScores {
                let label = data.scoreLabel ?? ""
                entryHTML += """
                <div class="score">\(entry.score)<span class="label"> \(escapeHTML(label))</span></div>
                """
            }
            
            entryHTML += "</div>"
            entriesHTML += entryHTML
        }
        
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
                    padding: 3% 5%;
                    height: 100vh;
                    overflow: hidden;
                    display: flex;
                    flex-direction: column;
                }
                
                .header {
                    text-align: center;
                    margin-bottom: 2.5vh;
                    opacity: 0;
                    animation: fadeInDown 0.8s ease-out forwards;
                }
                
                h1 {
                    font-family: \(titleFont);
                    font-size: 4.5vw;
                    font-weight: 700;
                    margin-bottom: 0.5vh;
                }
                
                .subtitle {
                    font-size: 2vw;
                    opacity: 0.7;
                }
                
                .entries {
                    flex: 1;
                    display: flex;
                    flex-direction: column;
                    gap: 1vh;
                    justify-content: center;
                    padding: 0 3%;
                }
                
                .entry {
                    display: flex;
                    align-items: center;
                    padding: 1.5vh 2vw;
                    background: rgba(255, 255, 255, 0.03);
                    border-radius: 0.8vw;
                    transform: translateY(30px);
                    opacity: 0;
                    animation: revealUp 0.5s ease-out forwards;
                    animation-delay: var(--delay);
                }
                
                .rank-number {
                    font-size: 3vw;
                    font-weight: 800;
                    min-width: 5vw;
                    color: \(textColor);
                    opacity: 0.6;
                }
                
                .name {
                    font-size: 2.5vw;
                    font-weight: 500;
                    flex: 1;
                    padding-left: 1vw;
                }
                
                .score {
                    font-size: 2.5vw;
                    font-weight: 700;
                    color: \(accentColor);
                    min-width: 12vw;
                    text-align: right;
                }
                
                .score .label {
                    font-size: 1.8vw;
                    font-weight: 400;
                    opacity: 0.7;
                }
                
                /* Animations */
                @keyframes fadeInDown {
                    from {
                        opacity: 0;
                        transform: translateY(-20px);
                    }
                    to {
                        opacity: 1;
                        transform: translateY(0);
                    }
                }
                
                @keyframes revealUp {
                    from {
                        opacity: 0;
                        transform: translateY(30px);
                    }
                    to {
                        opacity: 1;
                        transform: translateY(0);
                    }
                }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>\(escapeHTML(data.title))</h1>
                <div class="subtitle">\(escapeHTML(data.subtitle ?? ""))</div>
            </div>
            <div class="entries">
                \(entriesHTML)
            </div>
        </body>
        </html>
        """
    }
    
    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
