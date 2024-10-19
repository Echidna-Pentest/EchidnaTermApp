//
//  Chat.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/05/29.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let message: String
    let isUser: Bool
}

class ChatViewModel: ObservableObject {
    static let shared = ChatViewModel()
    @Published var messages: [ChatMessage] = [
        ChatMessage(message: "If you enable the AI ​​Analysis option on the API Key page and register your OpenAI API Key, the terminal output will be analyzed using the OpenAI API.", isUser: false),
        ChatMessage(message: "If you add @AI to the beginning, Echidna will analyze the received text using the OpenAI API.", isUser: false),
    ]
    
    func sendMessage(_ message: String, isUser: Bool) {
        let chatMessage = ChatMessage(message: message, isUser: isUser)
        messages.append(chatMessage)
        
        if isUser && message.hasPrefix("@AI") {
            handleAICommand(message: message, fromUserRequest: true)
        }
    }
    
    private func handleAICommand(message: String, fromUserRequest: Bool) {
        APIManager.shared.performOpenAIAnalysis(text: message, fromUserRequest: fromUserRequest)
    }
}

struct ChatView: View {
    //@ObservedObject var viewModel = ChatViewModel()
    @ObservedObject var viewModel = ChatViewModel.shared
    //    @EnvironmentObject var viewModel: ChatViewModel
    @State private var newMessage: String = ""

    var body: some View {
        VStack {
            List {
                ForEach(viewModel.messages) { message in
                    HStack {
                        if message.isUser {
                            Spacer()
                            Text(message.message)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        } else {
                            Text(message.message)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.black)
                                .cornerRadius(8)
                            Spacer()
                        }
                    }
                    .padding(message.isUser ? .leading : .trailing, 40)
                }
            }
            .listStyle(PlainListStyle())
            
            HStack {
                TextField("Type your message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: CGFloat(30))
                
                Button(action: {
                    viewModel.sendMessage(newMessage, isUser: true)
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
