//
//  AddCommandView.swift
//  EchidnaTermApp
//
//  Created by Terada Yu on 2024/07/03.
//  Copyright © 2024 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct AddCommandView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var pattern: String = ""
    @State private var description: String = ""
    @State private var template: String = ""
    @State private var condition: String = ""
    @State private var group: String = ""
    
    var onSave: (Command) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Pattern")) {
                    TextField("Pattern", text: $pattern)
                }
                Section(header: Text("Description")) {
                    TextField("Description", text: $description)
                }
                Section(header: Text("Template")) {
                    TextField("Template", text: $template)
                }
                Section(header: Text("Condition (comma-separated)")) {
                    TextField("Condition", text: $condition)
                }
                Section(header: Text("Group")) {
                    TextField("Group", text: $group)
                }
            }
            .navigationBarTitle("Add Command", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                let conditions: [String] = condition.isEmpty ? [] : condition.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let newCommand = Command(
                    template: template,
                    patterns: [pattern],
                    condition: conditions,
                    group: group.isEmpty ? nil : group,
                    description: description
                )
                onSave(newCommand)
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
