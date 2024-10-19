//
//  AddAPIKeysView.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/07/01.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import SwiftUI
import Security

struct AddEditAPIKeyView: View {
    @Binding var isPresented: Bool
    @Binding var apiKey: String?
    @State private var inputKey: String = ""
    var service: String
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Enter API Key", text: $inputKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: saveKey) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Add/Edit API Key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            if let existingKey = apiKey {
                inputKey = existingKey
            }
        }
    }
    
    func saveKey() {
        saveAPIKey(service: service, apiKey: inputKey)
        apiKey = inputKey
        isPresented = false
    }
    
    func saveAPIKey(service: String, apiKey: String) {
        let keyData = apiKey.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: keyData
        ]
        
        // Remove existing key if it exists
        SecItemDelete(query as CFDictionary)
        
        // Add new key
        SecItemAdd(query as CFDictionary, nil)
    }
}

