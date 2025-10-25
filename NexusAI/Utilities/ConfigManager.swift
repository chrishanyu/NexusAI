//
//  ConfigManager.swift
//  NexusAI
//
//  Created on October 25, 2025.
//

import Foundation

/// Manages application configuration from Config.plist
struct ConfigManager {
    static let shared = ConfigManager()
    
    /// OpenAI API key for AI assistant features
    private(set) var openAIAPIKey: String
    
    private init() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let apiKey = config["OPENAI_API_KEY"] as? String, !apiKey.isEmpty else {
            fatalError("Config.plist not found or OPENAI_API_KEY is missing/empty. Please create Config.plist with your OpenAI API key.")
        }
        self.openAIAPIKey = apiKey
    }
}

