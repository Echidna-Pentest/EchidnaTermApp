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
        case "command_score":
            return """
            Score each command from 0 to 100 based on its relevance for exploiting vulnerabilities or obtaining critical information in a penetration testing context.

            Requirements:
            - Ensure the number of scores matches the number of commands.
            - Ensure the scores are in the same order as the commands.
            - Before returning the result, double-check that the count of scores is equal to the count of commands. If they do not match, adjust the scores and reanalyze until they match.

            Output:
            - Return only a JSON object with the scores list in the format: {"scores": [score1, score2, ...]}.
            - If, after multiple adjustments, the counts still do not match, return an error in JSON format: {"error": "Mismatched score and command count"}.

            Commands:
            \(input)
            """
        default:
            return "Analyze the following input: \(input)"
        }
    }
    
    
    func scoreCommands(_ commands: [Command], completion: @escaping (Result<[Int], Error>) -> Void) {

        // Create a description of the commands with their display names and enumerate them
        let commandDescriptions = commands.map { $0.displayName }.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
//        print("commandDescriptions=", commandDescriptions)
        // Define the prompt for scoring the commands
        let parameters: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": generatePrompt(input: commandDescriptions, analysisType: "command_score")]
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

//        print("score: parameters=", parameters)
        sendRequestToGemini(parameters: parameters, completion: completion)  // Call function to send request to Gemini API
    }

    private func sendRequestToGemini(parameters: [String: Any], completion: @escaping (Result<[Int], Error>) -> Void) {
        guard let geminiApiKey = APIManager.shared.retrieveAPIKey(service: "GeminiKeyService"),
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=\(geminiApiKey)") else {
            completion(.failure(GeminiClientError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Serialize request body
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let jsonString = String(data: data, encoding: .utf8) else {
                completion(.failure(OpenAIClientError.noData))
                return
            }
            
//            print("Raw Response: \(jsonString)")

            // Parse response to get scores
            if let scores = self.extractScores(from: jsonString) {
                completion(.success(scores))
            } else {
                print("Failed to parse scores from response. Raw Response: \(jsonString)")
                completion(.failure(OpenAIClientError.apiError("Failed to parse scores from response.")))
            }
        }
        task.resume()
    }

    // Enhanced helper function to parse scores from JSON response
    private func extractScores(from jsonString: String) -> [Int]? {
        // Step 1: Parse initial JSON structure
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonResponse = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
              let candidates = jsonResponse["candidates"] as? [[String: Any]] else {
            print("Error: Failed to parse the base JSON structure.")
            return nil
        }
        
        // Step 2: Access `text` within `content -> parts -> text`
        guard let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            print("Error: Could not find 'text' field within JSON response.")
            return nil
        }
        
        // Step 3: Remove Markdown backticks and locate JSON content
        let cleanedText = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Step 4: Extract JSON inside cleaned text
        guard let jsonStart = cleanedText.range(of: "{"),
              let jsonEnd = cleanedText.range(of: "}", options: .backwards)?.upperBound else {
            print("Error: No JSON structure found in 'text' field.")
            return nil
        }
        
        let jsonText = String(cleanedText[jsonStart.lowerBound..<jsonEnd])
        
        // Step 5: Parse extracted JSON to access `scores`
        guard let contentData = jsonText.data(using: .utf8),
              let parsedContent = try? JSONSerialization.jsonObject(with: contentData, options: []) as? [String: Any],
              let scores = parsedContent["scores"] as? [Int] else {
            print("Error: Failed to parse scores from extracted JSON.")
            return nil
        }
        
        return scores
    }

}
