//
//  Chat.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/05/29.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import SwiftUI

class ChatViewModel: ObservableObject {
    static let shared = ChatViewModel()
    
    @Published var messages: [(message: String, source: Int)] = [
        ("If you enable the AI ​​Analysis option on the API Key page and register your OpenAI or Gemini API Key, the terminal output will be analyzed using their APIs.", 0),
        ("If you add @AI to the beginning, Echidna will analyze the received text using the OpenAI API.", 0),
        ("If you add @Gemini to the beginning, Echidna will analyze the received text using the Gemini API.", 0)
    ]
    
    func removeAtPrefix(from message: String) -> String {
        // Replace the part from @ to the first space using regular expression
        let modifiedMessage = message.replacingOccurrences(of: "^@\\S+\\s", with: "", options: .regularExpression)
        return modifiedMessage
    }
    
    func sendMessage(_ message: String, source: Int) {
        messages.append((message: message, source: source))
        
        if source == 1 && (message.hasPrefix("@AI") || !message.hasPrefix("@")) {
            handleAICommand(message: message)
        }
        
        if source == 1 && (message.hasPrefix("@Gemini") || !message.hasPrefix("@")) {
//            print("for Gemini: message=", removeAtPrefix(from: message))
            GeminiAPIManager.shared.analyzeTextByGemini(input: removeAtPrefix(from: message), isUserRequest: true) { result in
                switch result {
                case .success(let text):
                    print("Success: \(text)")
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
        }
        // Check if the source is for Local processing and if the message has the correct prefix
        if source == 1 && (message.hasPrefix("@Local") || !message.hasPrefix("@")) {
            // Run the asynchronous operation within a Task context to support async calls
            Task {
                // Initialize the LocalLLM instance and provide a progress handler
                if let LocalLLM = await LocalLLM.getInstance(update: { progress in
                    print("Loading progress: \(progress)")
                }) {
                    // Perform analysis with LocalLLM and handle the result
                    let result = await LocalLLM.performLocalAIAnalysis(input: removeAtPrefix(from: message), fromUserRequest: true)
                } else {
                    print("Failed to initialize LocalLLM instance")
                }
            }
        }

    }
    
    private func handleAICommand(message: String) {
//        messages.append((message: message, source: 2))  // Add as a message from OpenAI
        APIManager.shared.performOpenAIAnalysis(text: message, fromUserRequest: true)
    }
}

struct ChatView: View {
    @ObservedObject var viewModel = ChatViewModel.shared
    @State private var newMessage: String = ""

    var body: some View {
        VStack {
            List {
                ForEach(viewModel.messages.indices, id: \.self) { index in
                    let message = viewModel.messages[index]
                    
                    HStack {
                        if message.source == 1 {  // User message
                            Spacer()
                            Text(message.message)
                                .padding()
                                .background(Color.blue)  // User messages are blue
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        } else if message.source == 2 {  // OpenAI message
                            Text(message.message)
                                .padding()
                                .background(Color.green.opacity(0.2))  // OpenAI messages are green
                                .foregroundColor(.black)
                                .cornerRadius(8)
                            Spacer()
                        } else if message.source == 3 {  // Gemini message
                            Text(message.message)
                                .padding()
                                .background(Color.purple.opacity(0.2))  // Gemini messages are purple
                                .foregroundColor(.black)
                                .cornerRadius(8)
                            Spacer()
                        } else {  // Other messages
                            Text(message.message)
                                .padding()
                                .background(Color.orange.opacity(0.2))  // Other messages are orange
                                .foregroundColor(.black)
                                .cornerRadius(8)
                            Spacer()
                        }
                    }
                    .padding(message.source == 1 ? .leading : .trailing, 40)
                }
            }
            .listStyle(PlainListStyle())
            
            HStack {
                TextField("Type your message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: CGFloat(30))
                
                Button(action: {
                    viewModel.sendMessage(newMessage, source: 1)  // 1 is for user
                    newMessage = ""
                }) {
                    Text("Send")
                }
                .padding()
            }
            .padding()
        }
    }
}
