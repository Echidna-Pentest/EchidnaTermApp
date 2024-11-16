//
//  APIManager.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/07/02.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation
import Security

struct AnalysisResult: Codable {
    struct CommandItem: Codable {
        let command: String
        let explanation: String?
    }
    let commands: [CommandItem]
    let vulnerability: String
}

class APIManager {
    
    static let shared = APIManager()
    
    private init() {}
    
    func performOpenAIAnalysis(text: String, fromUserRequest: Bool = false) {
        guard fromUserRequest || UserDefaults.standard.bool(forKey: "EnableOpenAIAnalysis") else {
            print("AI Analysis is disabled.")
            return
        }
        
        guard let apiKey = retrieveAPIKey() else {
            print("API Key not found.")
            return
        }

        let client = OpenAIClient(apiKey: apiKey)

        client.analyzeText(input: text, analysisType: "penetration_testing", isUserRequest: fromUserRequest) { result in
            switch result {
            case .success(let analysis):
//                print("analysis=", analysis)

                if fromUserRequest {
//                    print("OpenAI Analysis Result: \(analysis)")
                    ChatViewModel.shared.sendMessage("OpenAI Response\n" + analysis, source: 2)
                    return
                }
                APIManager.processAnalysis(analysis: analysis, llmName: "OpenAI", source: 2)

                // Send the analysis data to the chat view model
//                let chatViewModel = ChatViewModel.shared
//                chatViewModel.sendMessage(analysis, isUser: false)

            case .failure(let error):
                // Handle analysis errors
                print("Analysis Error: \(error)")
            }
        }

    }
    
    static func processAnalysis(analysis: String, llmName: String, source: Int) {
        // Convert analysis from String to Data
        guard let jsonData = analysis.data(using: .utf8) else {
            print("Error converting analysis to Data")
            return
        }

        do {
            // Decode the entire analysis result JSON object
            let analysisResult = try JSONDecoder().decode(AnalysisResult.self, from: jsonData)
            
            // Iterate through the commands and add them
            for commandObj in analysisResult.commands {
                let newCommand = Command(
                    template: commandObj.command,
                    patterns: [],
                    condition: [],
                    group: llmName, // Use the provided LLM name here
                    description: commandObj.explanation ?? ""
                )
                CommandManager.shared.addCommand(newCommand)
            }
            
            // Output the most concerning vulnerability
            if !analysisResult.vulnerability.contains("NONE") {
                ChatViewModel.shared.sendMessage("\(llmName) Analysis\n" + analysisResult.vulnerability, source: source)
            }
        } catch {
            // Handle decoding errors
            print("Error decoding JSON: \(error)")
        }
    }

    func retrieveAPIKey(service: String = "OpenAIKeyService") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess {
            if let keyData = item as? Data,
               let key = String(data: keyData, encoding: .utf8) {
//                print("retrieveAPIKey: key=", key)
                return key
            }
        }
        
        return nil
    }
}
