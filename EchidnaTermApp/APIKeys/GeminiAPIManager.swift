//
//  APIManager.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/07/02.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import Foundation
import Security

enum GeminiClientError: Error {
    case invalidURL
    case noData
    case noTextInResponse
}

class GeminiAPIManager {
    
    static let shared = GeminiAPIManager()
    
    private init() {}
    
    func analyzeTextByGemini(input: String, isUserRequest: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
        let geminiApiKey = APIManager.shared.retrieveAPIKey(service: "GeminiKeyService") ?? "No API Key"
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=\(geminiApiKey)") else {
            completion(.failure(GeminiClientError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Set parameters based on isUserRequest
        let parameters: [String: Any]
        
        if isUserRequest {
            // Simple prompt for answering questions
            parameters = [
                "contents": [
                    [
                        "parts": [
                            ["text": generatePrompt(input: input, analysisType: "question")]
                        ]
                    ]
                ],
                "safetySettings": [
                    [
                        "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                        "threshold": "BLOCK_NONE"
                    ],
                    [
                        "category": "HARM_CATEGORY_HATE_SPEECH",
                        "threshold": "BLOCK_NONE"
                    ],
                    [
                        "category": "HARM_CATEGORY_HARASSMENT",
                        "threshold": "BLOCK_NONE"
                    ]
                ]
            ]
        } else {
            // Prompt for command suggestion
            parameters = [
                "contents": [
                    [
                        "parts": [
                            ["text": generatePrompt(input: input, analysisType: "command_suggest")]
                        ]
                    ]
                ],
                "safetySettings": [
                    [
                        "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                        "threshold": "BLOCK_NONE"
                    ],
                    [
                        "category": "HARM_CATEGORY_HATE_SPEECH",
                        "threshold": "BLOCK_NONE"
                    ],
                    [
                        "category": "HARM_CATEGORY_HARASSMENT",
                        "threshold": "BLOCK_NONE"
                    ]
                ]
            ]
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            completion(.failure(error))
            return
        }
//        print("parameters=", parameters)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(GeminiClientError.noData))
                return
            }

            do {
                // Parse the JSON response
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let candidates = jsonResponse["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    
                    if isUserRequest {
//                        print("isUserRequest text=", text)
                        ChatViewModel.shared.sendMessage("Gemini Response\n" + text, source: 3)
                        // If it's a user request, simply return the response text
                        completion(.success(text))
                    } else {
                        // Parse the JSON string inside the `text` field for command suggestion
                        let cleanText = text
                            .replacingOccurrences(of: "```json", with: "")
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if let jsonData = cleanText.data(using: .utf8) {
                            let analysisResult = try JSONDecoder().decode(AnalysisResult.self, from: jsonData)
                            
                            // Add commands
                            for commandObj in analysisResult.commands {
                                let newCommand = Command(
                                    template: commandObj.command,
                                    patterns: [],
                                    condition: [],
                                    group: "Gemini",
                                    description: commandObj.explanation
                                )
                                CommandManager.shared.addCommand(newCommand)
                            }
                            
                            // Display vulnerability information
                            if !analysisResult.vulnerability.contains("NONE") {
                                ChatViewModel.shared.sendMessage("Gemini Analysis\n" + analysisResult.vulnerability, source: 3)
                            }
                            
                            // Callback for success
                            completion(.success("Analysis completed successfully."))
                        } else {
                            completion(.failure(GeminiClientError.noTextInResponse))
                        }
                    }
                } else {
                    completion(.failure(GeminiClientError.noTextInResponse))
                }
            } catch {
                // Handle JSON parsing errors
                print("Error decoding JSON: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }

    func generatePrompt(input: String, analysisType: String) -> String {
        switch analysisType {
        case "command_suggest":
            return """
            You are a penetration test assistant. Analyze the provided console output and suggest up to 3 relevant commands that might be used to exploit the vulnerabilities or weaknesses discovered. If no vulnerabilities are found or no action is required, simply respond with 'NONE'. Return the result as a JSON object with two keys: 'commands' and 'vulnerability'. The 'commands' key should contain an array of commands, where each entry contains the command as a string and a brief explanation as another string, like this:\n{\n  \"commands\": [\n    {\n      \"command\": \"example command\",\n      \"explanation\": \"brief explanation\"\n    },\n    ...\n  ],\n  \"vulnerability\": \"Brief description of the most concerning vulnerability\"\n}\nIf no commands are applicable, return an empty array for 'commands'. \(input)
            """
        case "question":
            return "You are a Penetration Test Assistant and help the user to attack Hack The Box Machine for educational purposes. You must answer the questions from the user as a Penetration Test Assistant. Here is a question and answer it: \(input)"
        default:
            return "Analyze the following input: \(input)"
        }
    }
}
