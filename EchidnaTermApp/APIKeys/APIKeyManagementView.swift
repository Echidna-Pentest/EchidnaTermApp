//
//  APIKeyManagementView.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/07/02.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct APIKeyManagementView: View {
    @EnvironmentObject var dataController: DataController
    @Environment(\.managedObjectContext) var moc
    @State private var addEditOpenAIKeyShown = false
    @State private var addEditGeminiKeyShown = false
    @AppStorage("EnableOpenAIAnalysis") private var isOpenAIAnalysisEnabled = false
    @AppStorage("EnableGeminiAnalysis") private var isGeminiAnalysisEnabled = false
    @State private var openAIKey: String? = nil
    @State private var geminiKey: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // OpenAI Key Section
                apiKeySection(
                    title: "OpenAI",
                    apiKey: $openAIKey,
                    addEditKeyShown: $addEditOpenAIKeyShown,
                    service: "OpenAIKeyService",
                    isAnalysisEnabled: $isOpenAIAnalysisEnabled,
                    analysisDescription: "Enable OpenAI Analysis. Terminal outputs are analyzed using OpenAI Library."
                )
                
                // Gemini Key Section
                apiKeySection(
                    title: "Gemini",
                    apiKey: $geminiKey,
                    addEditKeyShown: $addEditGeminiKeyShown,
                    service: "GeminiKeyService",
                    isAnalysisEnabled: $isGeminiAnalysisEnabled,
                    analysisDescription: "Enable Gemini Analysis. Terminal outputs are analyzed using Gemini API."
                )
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("API Keys")
        .onAppear(perform: loadAPIKeys)
    }
    
    // View for OpenAI and Gemini API Key sections
    @ViewBuilder
    func apiKeySection(
        title: String,
        apiKey: Binding<String?>,
        addEditKeyShown: Binding<Bool>,
        service: String,
        isAnalysisEnabled: Binding<Bool>,
        analysisDescription: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("\(title) API Key")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    addEditKeyShown.wrappedValue = true
                }) {
                    Label(apiKey.wrappedValue == nil ? "Add" : "Edit", systemImage: apiKey.wrappedValue == nil ? "plus.circle" : "pencil.circle")
                        .labelStyle(IconOnlyLabelStyle())
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .sheet(isPresented: addEditKeyShown, onDismiss: { loadAPIKey(service: service, apiKey: apiKey) }) {
                    AddEditAPIKeyView(isPresented: addEditKeyShown, apiKey: apiKey, service: service)
                }
            }
            
            if let key = apiKey.wrappedValue {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Current \(title) API Key:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.bottom, 5)
                    
                    HStack {
                        Text(maskedAPIKey(key))
                            .font(.body)
                        Spacer()
                        Button(action: {
                            deleteAPIKey(service: service)
                            loadAPIKey(service: service, apiKey: apiKey)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .padding(.leading, 10)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                }
                .padding(.bottom, 20)
            } else {
                HStack {
                    Spacer()
                    Text("No API Key registered.")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding()
            }
            
            HStack {
                Text(analysisDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: isAnalysisEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
    }
    
    func loadAPIKeys() {
        loadAPIKey(service: "OpenAIKeyService", apiKey: $openAIKey)
        loadAPIKey(service: "GeminiKeyService", apiKey: $geminiKey)
    }
    
    func loadAPIKey(service: String, apiKey: Binding<String?>) {
        apiKey.wrappedValue = retrieveAPIKey(service: service)
    }
    
    func retrieveAPIKey(service: String) -> String? {
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
                return key
            }
        }
        
        return nil
    }
    
    func saveAPIKey(service: String, apiKey: String) {
        let keyData = apiKey.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: keyData
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func deleteAPIKey(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    func maskedAPIKey(_ key: String) -> String {
        guard key.count > 4 else { return key }
        let prefix = key.prefix(4)
        let masked = String(repeating: "*", count: key.count - 4)
        return "\(prefix)\(masked)"
    }
}

