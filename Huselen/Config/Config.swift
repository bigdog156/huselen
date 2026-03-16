//
//  Config.swift
//  HuselenClient
//
//  Configuration file for API keys and app settings
//

import Foundation

enum Config {
    enum MEALAI {
        static var apiKey: String {
            // First try Info.plist (allows build-time injection via xcconfig/CI)
            if let infoKey = Bundle.main.object(forInfoDictionaryKey: "MEAL_KEY") as? String, !infoKey.isEmpty {
                return infoKey
            }
            
            // Next try environment variable (useful for local runs / scheme env vars)
            if let envKey = ProcessInfo.processInfo.environment["MEAL_KEY"], !envKey.isEmpty {
                return envKey
            }
            
             // Fallback to hardcoded key (replace with your key for development)
             // WARNING: Do not commit your API key to version control!
             return ""
         }
        
        static let visionModel = "gpt-5-nano"
        
        /// Max tokens for response
        static let maxTokens = 5000
        
        /// API Base URL
        static let baseURL = "https://api.openai.com/v1/chat/completions"
    }
    
    // MARK: - App Configuration
    enum App {
        /// Default calorie goal
        static let defaultCalorieGoal = 2000
        
        /// Default protein goal (grams)
        static let defaultProteinGoal = 50
        
        /// Default carbs goal (grams)
        static let defaultCarbsGoal = 250
        
        /// Default fat goal (grams)
        static let defaultFatGoal = 65
    }
}
