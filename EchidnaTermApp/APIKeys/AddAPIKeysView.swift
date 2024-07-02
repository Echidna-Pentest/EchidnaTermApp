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
    @State private var apiKey: String = ""
    @EnvironmentObject var dataController: DataController
    @Environment(\.managedObjectContext) var moc
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Key")) {
                    TextField("API Key", text: $apiKey)
                }
                
                Button(action: {
                    saveAPIKey(newKey: apiKey)
                    self.isPresented = false
                }) {
                    Text("Save")
                }
            }
            .navigationTitle("Add/Edit API Key")
            .navigationBarItems(trailing: Button("Cancel") {
                self.isPresented = false
            })
            .onAppear {
                self.apiKey = retrieveAPIKey() ?? ""
            }
        }
    }
    
    func saveAPIKey(newKey: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "APIKeyService"
        ]
        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "APIKeyService",
            kSecAttrAccount as String: UUID().uuidString,
            kSecValueData as String: newKey.data(using: .utf8)!
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        print("Save status: \(status)")
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
}
