//
//  OpenAIClient.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/05/31.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//
import Foundation

class OpenAIClient {
    private let apiKey: String
    private let apiUrl = "https://api.openai.com/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func scoreCommands(_ commands: [Command], completion: @escaping (Result<[Int], Error>) -> Void) {
        let commandDescriptions = commands.map { $0.displayName }.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
        let prompt = """
        Please evaluate the following commands from 0 to 100 based on their likelihood of being the next command to run. 

        1. **If the command is directly related to exploiting the machine (e.g., an exploit command), give it a higher score.** If the command is less effective or unlikely to yield useful results, give it a lower score.
        2. **Make sure that the order of the returned command scores matches the order of the commands provided. Do not change the order.**

        Return only the scores in JSON format as a list of integers, like:
        {"scores": [85, 90, 92, 88]}

        \(commandDescriptions)
        """
        
        let parameters: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": "You are a penetration testing assistant."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 200,
            "temperature": 0.2,
            "top_p": 0.2,
            "frequency_penalty": 0.0,
            "presence_penalty": 0.0
        ]
        
        sendRequestToOpenAI(parameters: parameters, completion: completion)
    }

    // Function to send the request to OpenAI API
    private func sendRequestToOpenAI(parameters: [String: Any], completion: @escaping (Result<[Int], Error>) -> Void) {
        guard let url = URL(string: apiUrl) else {
            completion(.failure(OpenAIClientError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
            
            guard let data = data else {
                completion(.failure(OpenAIClientError.noData))
                return
            }

            // Debug output: print the raw response data
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw Response: \(jsonString)")
            }

            do {
                // Parse the outer JSON to extract the content field
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = jsonResponse["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // Parse the JSON string contained in the 'content' field
                    if let contentData = content.data(using: .utf8),
                       let parsedContent = try? JSONSerialization.jsonObject(with: contentData, options: []) as? [String: Any],
                       let scores = parsedContent["scores"] as? [Int] {
                        completion(.success(scores))
                    } else {
                        completion(.failure(OpenAIClientError.apiError("Invalid content format")))
                    }
                    
                } else {
                    completion(.failure(OpenAIClientError.apiError("Invalid response format")))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }


    
    func analyzeText(input: String, analysisType: String, isUserRequest: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: apiUrl) else {
            completion(.failure(OpenAIClientError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var parameters: [String: Any]

        if isUserRequest {
            parameters = [
                "model": "gpt-4",
                "messages": [
                    ["role": "system", "content": "You are a penetration test assistant. Respond to the user's questions or requests\n"],
                    ["role": "user", "content": generatePrompt(input: input, analysisType: analysisType)]
                ],
                "max_tokens": 500,
                "temperature": 0.3,
                "top_p": 0.9,
                "frequency_penalty": 0.0,
                "presence_penalty": 0.0
            ]
        } else {
            parameters = [
                "model": "gpt-4",
                "messages": [
                    ["role": "system", "content": "You are a penetration test assistant. Analyze the provided console output and suggest up to 3 relevant commands that might be used to exploit the vulnerabilities or weaknesses discovered. If no vulnerabilities are found or no action is required, simply respond with 'NONE'. Return the result as a JSON object with two keys: 'commands' and 'vulnerability'. The 'commands' key should contain an array of commands, where each entry contains the command as a string and a brief explanation as another string, like this:\n{\n  \"commands\": [\n    {\n      \"command\": \"example command\",\n      \"explanation\": \"brief explanation\"\n    },\n    ...\n  ],\n  \"vulnerability\": \"Brief description of the most concerning vulnerability\"\n}\nIf no commands are applicable, return an empty array for 'commands'."],
                    ["role": "user", "content": generatePrompt(input: input, analysisType: analysisType)]
                ],
                "max_tokens": 400,
                "temperature": 0.3,
                "top_p": 0.3,
                "frequency_penalty": 0.0,
                "presence_penalty": 0.0
            ]
        }
            
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
            
            guard let data = data else {
                completion(.failure(OpenAIClientError.noData))
                return
            }

            do {
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let errorMessage = jsonResponse["error"] as? [String: Any],
                   let message = errorMessage["message"] as? String {
                    completion(.failure(OpenAIClientError.apiError(message)))
                    return
                }
                
                let result = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                if let text = result.choices.first?.message.content {
                    completion(.success(text))
                } else {
                    completion(.failure(OpenAIClientError.noTextInResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func generatePrompt(input: String, analysisType: String) -> String {
        switch analysisType {
        case "penetration_testing":
            return "Respond to the the following text: \(input)"
        case "summarize":
            return "Summarize the following text: \(input)"
        case "translate":
            return "Translate the following text to French: \(input)"
        default:
            return input
        }
    }
}

struct OpenAIChatResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

enum OpenAIClientError: Error {
    case invalidURL
    case noData
    case apiError(String)
    case noTextInResponse
}
