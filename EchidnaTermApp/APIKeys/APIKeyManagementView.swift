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
        VStack {
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
            
            Toggle(isOn: $isAIAnalysisEnabled) {
                Text("Enable AI Analysis")
            }
            .padding()
            
            if let apiKey = apiKey {
                VStack {
                    HStack {
                        Text("Current API Key")
                            .font(.headline)
                        Spacer()
                    }
                    .padding([.top, .horizontal])
                    
                    HStack {
                        Text(maskedAPIKey(apiKey))
                        Spacer()
                        Button(action: {
                            self.addEditKeyShown = true
                        }) {
                            Image(systemName: "pencil")
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
                HStack(alignment: .top) {
                    Image(systemName: "key")
                        .font(.title)
                    Text("No API Key registered. Add an API Key to enable secure access to APIs.")
                        .font(.body)
                }
                .padding()
                Spacer()
            }
        }
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
