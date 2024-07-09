//
//  APIManager.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/07/02.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation
import Security

class APIManager {
    
    static let shared = APIManager()
    
    private init() {}
    
    func performAIAnalysis(text: String, fromUserRequest: Bool = false) {
        guard fromUserRequest || UserDefaults.standard.bool(forKey: "EnableAIAnalysis") else {
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
                let chatViewModel = ChatViewModel.shared
                chatViewModel.sendMessage(analysis, isUser: false)
            case .failure(let error):
                print("Analysis Error: \(error)")
            }
        }
    }

    private func retrieveAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "APIKeyService",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess {
            if let keyData = item as? Data,
               let key = String(data: keyData, encoding: .utf8) {
                return key
            }
        }
        
        return nil
    }
}
