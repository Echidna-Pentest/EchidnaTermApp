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
    @State private var addEditKeyShown = false
    @AppStorage("EnableAIAnalysis") private var isAIAnalysisEnabled = false
    @State private var apiKey: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: {
                    self.addEditKeyShown = true
                }) {
                    Label(apiKey == nil ? "Add API Key" : "Edit API Key", systemImage: "plus.circle")
                        .font(.title2)
                        .padding()
                }
                .sheet(isPresented: $addEditKeyShown, onDismiss: loadAPIKey) {
                    AddEditAPIKeyView(isPresented: $addEditKeyShown)
                }
                Spacer()
            }
            
            HStack {
                Text("Enable OpenAI Analysis. If this is enabled, terminal outputs are analyzed using OpenAI Library")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $isAIAnalysisEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding()
            
            if let apiKey = apiKey {
                VStack(spacing: 10) {
                    HStack {
                        Text("Current API Key")
                            .font(.headline)
                        Spacer()
                    }
                    .padding([.top, .horizontal])
                    
                    HStack {
                        Text(maskedAPIKey(apiKey))
                            .font(.body)
                        Spacer()
                        Button(action: {
                            self.addEditKeyShown = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    
                    Button(action: {
                        deleteAPIKey()
                        loadAPIKey()
                    }) {
                        Text("Delete API Key")
                            .foregroundColor(.red)
                    }
                    .padding()
                }
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding()
            } else {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "key")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No API Key registered.")
                        .font(.headline)
                    Text("Add an API Key to enable secure access to APIs.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                Spacer()
            }
        }
        .padding()
        .navigationTitle("API Keys")
        .onAppear(perform: loadAPIKey)
    }
    
    func loadAPIKey() {
        apiKey = retrieveAPIKey()
    }
    
    func retrieveAPIKey() -> String? {
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
    
    func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "APIKeyService"
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
